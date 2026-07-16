// Package recipes indexes recipe JSON files packaged inside the mod
// jars of a Prism instance.
//
// A mod jar's recipes live at:
//
//	data/<namespace>/recipe/<path>.json     (post-1.21)
//	data/<namespace>/recipes/<path>.json    (pre-1.21)
//
// Both are plain data-pack JSON; this package treats each recipe as an
// opaque map[string]any and lets callers walk it. A recipe's "output"
// is heuristically extracted for search.
package recipes

import (
	"archive/zip"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path"
	"strings"

	"github.com/gastrodon/mcp-minecraft/internal/prism"
)

// Match is a single hit from Find.
type Match struct {
	// Mod is the source jar filename (e.g. "create-1.21.1-6.0.1.jar").
	Mod string `json:"mod"`
	// Namespace is the data namespace under data/, typically the mod id.
	Namespace string `json:"namespace"`
	// Path is the recipe id path (e.g. "mixing/andesite_alloy").
	Path string `json:"path"`
	// Type is the recipe type from the JSON (e.g. "create:mixing").
	Type string `json:"type,omitempty"`
	// Output is the extracted result item id, best-effort.
	Output string `json:"output,omitempty"`
	// Raw is the full recipe JSON as a decoded value.
	Raw map[string]any `json:"raw"`
}

// Find walks every jar under <instance>/mods/*.jar and returns recipes
// whose id, output, or type contains query (case-insensitive). Up to
// limit matches are returned. query="" returns the first limit
// recipes found.
func Find(ctx context.Context, inst *prism.Instance, query string, limit int) ([]Match, error) {
	if inst == nil {
		return nil, errors.New("nil instance")
	}
	modsDir := inst.Path("mods")
	entries, err := os.ReadDir(modsDir)
	if err != nil {
		return nil, err
	}
	needle := strings.ToLower(query)

	var out []Match
	for _, e := range entries {
		if ctx.Err() != nil {
			return out, ctx.Err()
		}
		if e.IsDir() || !strings.HasSuffix(strings.ToLower(e.Name()), ".jar") {
			continue
		}
		matches, err := scanJar(path.Join(modsDir, e.Name()), needle, limit-len(out))
		if err != nil {
			// Log-only in real usage; for now skip broken jars silently.
			continue
		}
		for i := range matches {
			matches[i].Mod = e.Name()
		}
		out = append(out, matches...)
		if len(out) >= limit {
			break
		}
	}
	return out, nil
}

func scanJar(jarPath, needle string, budget int) ([]Match, error) {
	if budget <= 0 {
		return nil, nil
	}
	zr, err := zip.OpenReader(jarPath)
	if err != nil {
		return nil, err
	}
	defer zr.Close()

	var out []Match
	for _, f := range zr.File {
		ns, rp, ok := parseRecipeEntry(f.Name)
		if !ok {
			continue
		}
		if len(out) >= budget {
			break
		}
		m, err := decodeRecipe(f)
		if err != nil {
			continue
		}
		m.Namespace = ns
		m.Path = rp
		if !matches(m, needle) {
			continue
		}
		out = append(out, m)
	}
	return out, nil
}

// parseRecipeEntry returns (namespace, path) if entryName is a recipe
// JSON inside a mod jar.
func parseRecipeEntry(entryName string) (namespace, recipePath string, ok bool) {
	// data/<ns>/recipe/<rest>.json  OR  data/<ns>/recipes/<rest>.json
	parts := strings.Split(entryName, "/")
	if len(parts) < 4 || parts[0] != "data" {
		return "", "", false
	}
	if !strings.HasSuffix(parts[len(parts)-1], ".json") {
		return "", "", false
	}
	switch parts[2] {
	case "recipe", "recipes":
	default:
		return "", "", false
	}
	rest := strings.Join(parts[3:], "/")
	rest = strings.TrimSuffix(rest, ".json")
	return parts[1], rest, true
}

func decodeRecipe(zf *zip.File) (Match, error) {
	rc, err := zf.Open()
	if err != nil {
		return Match{}, err
	}
	defer rc.Close()
	data, err := io.ReadAll(rc)
	if err != nil {
		return Match{}, err
	}
	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		return Match{}, err
	}
	m := Match{Raw: raw}
	if t, ok := raw["type"].(string); ok {
		m.Type = t
	}
	m.Output = extractOutput(raw)
	return m, nil
}

// extractOutput best-effort walks the common shapes for a recipe's
// result and returns a resource id like "modid:item_name".
func extractOutput(r map[string]any) string {
	// "result": "modid:item"
	// "result": {"item": "modid:item", ...}
	// "result": {"id": "modid:item", ...}
	// "results": [ ... ] (Create)
	// "output": similar shapes
	for _, k := range []string{"result", "output"} {
		if v, ok := r[k]; ok {
			if id := idOf(v); id != "" {
				return id
			}
		}
	}
	if v, ok := r["results"]; ok {
		if arr, ok := v.([]any); ok && len(arr) > 0 {
			if id := idOf(arr[0]); id != "" {
				return id
			}
		}
	}
	return ""
}

func idOf(v any) string {
	switch x := v.(type) {
	case string:
		return x
	case map[string]any:
		for _, k := range []string{"item", "id"} {
			if s, ok := x[k].(string); ok {
				return s
			}
		}
	}
	return ""
}

func matches(m Match, needle string) bool {
	if needle == "" {
		return true
	}
	for _, s := range []string{m.Output, m.Type, m.Namespace + ":" + m.Path} {
		if strings.Contains(strings.ToLower(s), needle) {
			return true
		}
	}
	return false
}
