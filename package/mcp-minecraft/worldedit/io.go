package worldedit

import (
	"errors"
	"io"
	"os"
)

// ErrNotImplemented is returned by IO functions until NBT
// (de)serialization is wired up.
var ErrNotImplemented = errors.New("worldedit: NBT IO not yet implemented — pending NBT dep")

// Read parses a Sponge .schem file (gzip-compressed NBT).
func Read(path string) (*Schematic, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return ReadFrom(f)
}

// ReadFrom parses a schematic from r (gzip-compressed NBT).
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

// EncodeBlockData varint-encodes s.Blocks into the Sponge V2 BlockData
// byte array. Exposed for tests and future use by WriteTo.
func EncodeBlockData(s *Schematic) []byte {
	// Sponge uses unsigned LEB128 (a.k.a. protobuf varint) over each
	// palette index, laid out X-then-Z-then-Y already in s.Blocks.
	out := make([]byte, 0, len(s.Blocks))
	for _, v := range s.Blocks {
		u := uint32(v)
		for {
			b := byte(u & 0x7f)
			u >>= 7
			if u != 0 {
				out = append(out, b|0x80)
				continue
			}
			out = append(out, b)
			break
		}
	}
	return out
}
