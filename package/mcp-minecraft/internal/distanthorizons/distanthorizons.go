// Package distanthorizons opens the sqlite databases Distant Horizons
// writes under minecraft/Distant_Horizons_server_data/<server>/.
//
// DH stores compressed LOD block data per column; this package
// currently exposes only DB discovery and schema inspection. Voxel
// decode belongs behind a more expressive query API and is left as a
// TODO.
package distanthorizons

import (
	"database/sql"
	"errors"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite" // pure-Go driver

	"github.com/gastrodon/mcp-minecraft/internal/prism"
)

// Server is one Distant Horizons cache entry (one MC server or world).
type Server struct {
	Name string `json:"name"`
	Path string `json:"path"`
}

// ListServers returns each cached DH world under the instance.
func ListServers(inst *prism.Instance) ([]Server, error) {
	root := inst.Path("Distant_Horizons_server_data")
	entries, err := os.ReadDir(root)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, nil
		}
		return nil, err
	}
	var out []Server
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		out = append(out, Server{Name: e.Name(), Path: filepath.Join(root, e.Name())})
	}
	return out, nil
}

// OpenSqlite opens the first .sqlite file under a DH server dir. The
// caller must close the returned *sql.DB.
func OpenSqlite(srv Server) (*sql.DB, error) {
	var found string
	err := filepath.Walk(srv.Path, func(p string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return err
		}
		if filepath.Ext(p) == ".sqlite" && found == "" {
			found = p
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	if found == "" {
		return nil, errors.New("no .sqlite file under " + srv.Path)
	}
	return sql.Open("sqlite", found+"?_pragma=journal_mode(WAL)&_pragma=busy_timeout(2000)&mode=ro")
}
