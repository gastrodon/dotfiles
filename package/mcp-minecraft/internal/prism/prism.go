// Package prism resolves Prism Launcher instance directories on disk.
package prism

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

// Instance is a single Prism Launcher instance on disk.
//
// Prism's layout under an instance directory is:
//
//	<Root>/
//	  instance.cfg
//	  mmc-pack.json
//	  minecraft/           <- MinecraftDir
//	    mods/
//	    logs/latest.log
//	    screenshots/
//	    saves/
//	    journeymap/
//	    Distant_Horizons_server_data/
type Instance struct {
	Name        string
	Root        string
	MinecraftDir string
}

// DataDir returns the path Prism uses for its data directory, honoring
// XDG_DATA_HOME. It does not check that the directory exists.
func DataDir() string {
	if d := os.Getenv("PRISM_DATA_DIR"); d != "" {
		return d
	}
	if x := os.Getenv("XDG_DATA_HOME"); x != "" {
		return filepath.Join(x, "PrismLauncher")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "share", "PrismLauncher")
}

// InstancesDir returns the instances/ directory under DataDir.
func InstancesDir() string {
	return filepath.Join(DataDir(), "instances")
}

// ListInstances returns the names of all instance directories.
func ListInstances() ([]string, error) {
	entries, err := os.ReadDir(InstancesDir())
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, nil
		}
		return nil, err
	}
	var out []string
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		if _, err := os.Stat(filepath.Join(InstancesDir(), e.Name(), "instance.cfg")); err == nil {
			out = append(out, e.Name())
		}
	}
	return out, nil
}

// Resolve returns the instance with the given name. If name is empty
// and exactly one instance exists, it returns that one; otherwise it
// returns an error asking the caller to disambiguate.
func Resolve(name string) (*Instance, error) {
	if name != "" {
		return open(name)
	}
	names, err := ListInstances()
	if err != nil {
		return nil, err
	}
	switch len(names) {
	case 0:
		return nil, fmt.Errorf("no Prism instances found under %s", InstancesDir())
	case 1:
		return open(names[0])
	default:
		return nil, fmt.Errorf("multiple instances found (%v); specify one via the `instance` argument", names)
	}
}

func open(name string) (*Instance, error) {
	root := filepath.Join(InstancesDir(), name)
	info, err := os.Stat(filepath.Join(root, "instance.cfg"))
	if err != nil || info.IsDir() {
		return nil, fmt.Errorf("no instance %q at %s", name, root)
	}
	return &Instance{
		Name:        name,
		Root:        root,
		MinecraftDir: filepath.Join(root, "minecraft"),
	}, nil
}

// Path joins parts onto the instance's minecraft/ directory.
func (i *Instance) Path(parts ...string) string {
	return filepath.Join(append([]string{i.MinecraftDir}, parts...)...)
}
