// Package litematica implements read and write support for the
// Litematica client-mod schematic format (.litematic).
//
// A .litematic file is a gzip-compressed NBT root compound with this
// shape (Litematica schematic_format.txt is the source of truth):
//
//	{
//	  Version: int
//	  SubVersion: int (optional)
//	  MinecraftDataVersion: int
//	  Metadata: {
//	    Name, Author, Description: string
//	    TimeCreated, TimeModified: long (ms since epoch)
//	    RegionCount: int
//	    TotalVolume: int
//	    TotalBlocks: int
//	    EnclosingSize: { x, y, z: int }
//	  }
//	  Regions: {
//	    <RegionName>: {
//	      Position: { x, y, z: int }
//	      Size: { x, y, z: int }         (may be negative to indicate direction)
//	      BlockStatePalette: [ { Name: string, Properties: {...} }, ... ]
//	      BlockStates: long[] (bit-packed palette indices; bits/index = ceil(log2(len(palette))))
//	      TileEntities: [ ... ]
//	      Entities: [ ... ]
//	      PendingBlockTicks / PendingFluidTicks: [ ... ]
//	    }
//	  }
//	}
package litematica

import "time"

// Version constants used when producing new files.
const (
	CurrentVersion  = 6 // Litematica schematic version
	CurrentSubVer   = 1
	CurrentDataVer  = 3955 // MC 1.21.1 DataVersion
)

// BlockState is a block id + optional property map.
type BlockState struct {
	Name       string            `json:"name" nbt:"Name"`
	Properties map[string]string `json:"properties,omitempty" nbt:"Properties,omitempty"`
}

// Vec3 is a Litematica integer vector.
type Vec3 struct {
	X int32 `nbt:"x"`
	Y int32 `nbt:"y"`
	Z int32 `nbt:"z"`
}

// Metadata is the schematic-level metadata compound.
type Metadata struct {
	Name          string    `nbt:"Name"`
	Author        string    `nbt:"Author"`
	Description   string    `nbt:"Description"`
	TimeCreated   int64     `nbt:"TimeCreated"`
	TimeModified  int64     `nbt:"TimeModified"`
	RegionCount   int32     `nbt:"RegionCount"`
	TotalVolume   int32     `nbt:"TotalVolume"`
	TotalBlocks   int32     `nbt:"TotalBlocks"`
	EnclosingSize Vec3      `nbt:"EnclosingSize"`
	PreviewImage  []int32   `nbt:"PreviewImageData,omitempty"`
	timestamp     time.Time // convenience for callers
}

// Region is one block region within a schematic. Litematica allows
// multiple regions per file; most tools produce a single region.
type Region struct {
	Position          Vec3
	Size              Vec3
	BlockStatePalette []BlockState
	// BlockStates is Litematica's bit-packed palette-index long array;
	// callers should use Blocks for a decoded []uint32 view.
	BlockStates []int64
	// Blocks is the decoded palette-index-per-voxel view, indexed as
	// [x + Size.X*(z + Size.Z*y)]. Populated by Decode.
	Blocks []uint32

	TileEntities []map[string]any
	Entities     []map[string]any
}

// Schematic is a full Litematica file in memory.
type Schematic struct {
	Version              int32
	SubVersion           int32
	MinecraftDataVersion int32
	Metadata             Metadata
	Regions              map[string]*Region
}

// New returns an empty single-region schematic sized w×h×d, ready for
// SetBlock calls.
func New(name string, w, h, d int32) *Schematic {
	now := time.Now().UnixMilli()
	return &Schematic{
		Version:              CurrentVersion,
		SubVersion:           CurrentSubVer,
		MinecraftDataVersion: CurrentDataVer,
		Metadata: Metadata{
			Name:          name,
			TimeCreated:   now,
			TimeModified:  now,
			RegionCount:   1,
			TotalVolume:   w * h * d,
			EnclosingSize: Vec3{X: w, Y: h, Z: d},
		},
		Regions: map[string]*Region{
			name: {
				Size:              Vec3{X: w, Y: h, Z: d},
				BlockStatePalette: []BlockState{{Name: "minecraft:air"}},
				Blocks:            make([]uint32, int(w)*int(h)*int(d)),
			},
		},
	}
}

// SetBlock writes a block into the first region at (x,y,z). Panics if
// the schematic has no regions.
func (s *Schematic) SetBlock(x, y, z int32, state BlockState) {
	r := s.firstRegion()
	idx := r.paletteIndex(state)
	r.Blocks[int(x)+int(r.Size.X)*(int(z)+int(r.Size.Z)*int(y))] = idx
	s.Metadata.TotalBlocks++
}

func (s *Schematic) firstRegion() *Region {
	for _, r := range s.Regions {
		return r
	}
	panic("schematic has no regions")
}

func (r *Region) paletteIndex(state BlockState) uint32 {
	for i, bs := range r.BlockStatePalette {
		if bs.Name == state.Name && stringMapsEqual(bs.Properties, state.Properties) {
			return uint32(i)
		}
	}
	r.BlockStatePalette = append(r.BlockStatePalette, state)
	return uint32(len(r.BlockStatePalette) - 1)
}

func stringMapsEqual(a, b map[string]string) bool {
	if len(a) != len(b) {
		return false
	}
	for k, v := range a {
		if b[k] != v {
			return false
		}
	}
	return true
}
