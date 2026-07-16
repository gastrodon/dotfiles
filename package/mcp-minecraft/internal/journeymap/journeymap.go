// Package journeymap surfaces JourneyMap tile data cached under the
// instance's minecraft/journeymap/ directory.
//
// TODO: JourneyMap writes per-region .png tiles and a companion
// binary chunk-heightmap file; this stub currently only lists the
// on-disk servers/worlds JourneyMap has seen. Wire tile lookup +
// PNG decode when it becomes the next-highest-value tool.
package journeymap

import (
	"errors"
	"os"
	"path/filepath"

	"github.com/gastrodon/mcp-minecraft/internal/prism"
)

// Snapshot is a snapshot of what JourneyMap has cached.
type Snapshot struct {
	// Worlds are the sub-directories under journeymap/data/(sp|mp)/.
	Worlds []string `json:"worlds"`
}

// Inventory walks journeymap/data/(sp|mp)/* and returns the known
// world dirs. Returns (nil, nil) if JourneyMap has not run yet.
func Inventory(inst *prism.Instance) (*Snapshot, error) {
	root := inst.Path("journeymap", "data")
	if _, err := os.Stat(root); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, nil
		}
		return nil, err
	}
	var out Snapshot
	for _, kind := range []string{"sp", "mp"} {
		kd := filepath.Join(root, kind)
		entries, err := os.ReadDir(kd)
		if err != nil {
			continue
		}
		for _, e := range entries {
			if e.IsDir() {
				out.Worlds = append(out.Worlds, kind+"/"+e.Name())
			}
		}
	}
	return &out, nil
}
