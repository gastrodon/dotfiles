// Package screenshots lists screenshot files under
// <mc>/screenshots/ newest-first.
package screenshots

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/gastrodon/mcp-minecraft/internal/prism"
)

// Screenshot is one image file.
type Screenshot struct {
	Path     string    `json:"path"`
	Modified time.Time `json:"modified"`
	SizeB    int64     `json:"size_bytes"`
}

// List returns up to limit screenshots, newest first.
func List(inst *prism.Instance, limit int) ([]Screenshot, error) {
	dir := inst.Path("screenshots")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	var out []Screenshot
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		lower := strings.ToLower(e.Name())
		if !(strings.HasSuffix(lower, ".png") || strings.HasSuffix(lower, ".jpg")) {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		out = append(out, Screenshot{
			Path:     filepath.Join(dir, e.Name()),
			Modified: info.ModTime(),
			SizeB:    info.Size(),
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Modified.After(out[j].Modified) })
	if len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}
