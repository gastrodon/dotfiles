// Package worldedit implements read and write support for the Sponge
// Schematic Specification (WorldEdit .schem, versions 2 and 3).
//
// A .schem file is gzip-compressed NBT with this shape (v2):
//
//	{
//	  Version: int (2 or 3)
//	  DataVersion: int
//	  Metadata: {...}
//	  Width, Height, Length: short
//	  Offset: int[3]
//	  Palette: { "<block>[<state>]": int, ... }
//	  PaletteMax: int
//	  BlockData: byte[]           (varint-encoded palette indices,
//	                               ordered X, then Z, then Y)
//	  BlockEntities: [ ... ]
//	  Entities: [ ... ]
//	}
//
// V3 splits blocks/biomes/entities into their own sub-compounds and
// uses "Data" instead of "BlockData"; support is stubbed and will
// pattern off the reader.
package worldedit

// Version constants.
const (
	SpongeV2       = 2
	SpongeV3       = 3
	CurrentVersion = SpongeV3
	// DataVersion for Minecraft 1.21.1.
	CurrentDataVersion = 3955
)

// PaletteKey is the "block[state=value,state2=value2]" form the Sponge
// spec uses as a palette map key.
type PaletteKey string

// Vec3i is a 3-int vector.
type Vec3i struct {
	X int32
	Y int32
	Z int32
}

// Schematic is a Sponge-format schematic in memory.
type Schematic struct {
	Version     int32
	DataVersion int32
	Metadata    map[string]any

	Width  int16
	Height int16
	Length int16
	Offset Vec3i

	// Palette maps the Sponge palette key ("modid:name[state=val,...]") to
	// the palette index used in Blocks.
	Palette map[PaletteKey]int32
	// Blocks holds palette indices ordered X, then Z, then Y:
	//   index = x + z*Width + y*Width*Length
	// Populated by Decode; encoded to BlockData at write time.
	Blocks []int32

	BlockEntities []map[string]any
	Entities      []map[string]any
}

// New returns an empty schematic sized w×h×l with an air palette entry.
func New(w, h, l int16) *Schematic {
	return &Schematic{
		Version:     CurrentVersion,
		DataVersion: CurrentDataVersion,
		Metadata:    map[string]any{},
		Width:       w,
		Height:      h,
		Length:      l,
		Palette: map[PaletteKey]int32{
			"minecraft:air": 0,
		},
		Blocks: make([]int32, int(w)*int(h)*int(l)),
	}
}

// SetBlock places a block at (x,y,z). key is the Sponge palette form
// ("modid:name" or "modid:name[state=value,...]"). Panics if out of bounds.
func (s *Schematic) SetBlock(x, y, z int16, key PaletteKey) {
	idx, ok := s.Palette[key]
	if !ok {
		idx = int32(len(s.Palette))
		s.Palette[key] = idx
	}
	s.Blocks[int(x)+int(z)*int(s.Width)+int(y)*int(s.Width)*int(s.Length)] = idx
}
