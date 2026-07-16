package litematica

import (
	"errors"
	"io"
	"math/bits"
	"os"
)

// ErrNotImplemented is returned by IO functions until NBT (de)serialization
// is wired up. The in-memory model in schematic.go is stable; only the disk
// bridge is pending.
var ErrNotImplemented = errors.New("litematica: NBT IO not yet implemented — pending NBT dep")

// Read parses a .litematic file (gzip-compressed NBT root).
func Read(path string) (*Schematic, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return ReadFrom(f)
}

// ReadFrom parses a Litematica schematic from r (gzip-compressed NBT).
func ReadFrom(r io.Reader) (*Schematic, error) {
	_ = r
	return nil, ErrNotImplemented
}

// Write serializes s to path (gzip-compressed NBT).
func Write(path string, s *Schematic) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	return WriteTo(f, s)
}

// WriteTo serializes s to w (gzip-compressed NBT).
func WriteTo(w io.Writer, s *Schematic) error {
	_ = w
	_ = s
	return ErrNotImplemented
}

// bitsPerIndex returns the number of bits per palette index used by the
// packed BlockStates long array. Litematica uses ceil(log2(paletteLen))
// with a minimum of 2.
func bitsPerIndex(paletteLen int) int {
	if paletteLen <= 4 {
		return 2
	}
	return bits.Len(uint(paletteLen - 1))
}

// PackBlocks bit-packs region.Blocks into region.BlockStates using
// Litematica's scheme (packed long array, no cross-long spanning up to
// version 6). This is exposed for tests and future use by WriteTo.
func PackBlocks(r *Region) {
	bpi := bitsPerIndex(len(r.BlockStatePalette))
	if bpi <= 0 {
		r.BlockStates = nil
		return
	}
	total := len(r.Blocks)
	longs := (total*bpi + 63) / 64
	out := make([]int64, longs)
	mask := uint64(1)<<uint(bpi) - 1
	for i, v := range r.Blocks {
		bitStart := i * bpi
		longIdx := bitStart / 64
		bitOffset := bitStart % 64
		out[longIdx] |= int64((uint64(v) & mask) << uint(bitOffset))
		if bitOffset+bpi > 64 {
			out[longIdx+1] |= int64((uint64(v) & mask) >> uint(64-bitOffset))
		}
	}
	r.BlockStates = out
}
