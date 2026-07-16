// mcp-minecraft is a Model Context Protocol server that exposes
// read-only perception of a Prism Launcher Minecraft instance:
// recipes indexed from mod jars, chat log tailing, screenshot listing,
// JourneyMap terrain, and Distant Horizons LOD queries. It also ships
// Litematica and WorldEdit schematic libraries so agents can produce
// blueprint artefacts on disk.
//
// It communicates over stdio and is intended to be launched by a client
// such as Claude Code via `mcp-minecraft`.
package main

import (
	"context"
	"log"
	"os"

	"github.com/modelcontextprotocol/go-sdk/mcp"

	"github.com/gastrodon/mcp-minecraft/internal/logs"
	"github.com/gastrodon/mcp-minecraft/internal/prism"
	"github.com/gastrodon/mcp-minecraft/internal/recipes"
	"github.com/gastrodon/mcp-minecraft/internal/screenshots"
)

const version = "0.1.0"

// instanceArg is embedded in every tool input; empty means "use the
// single instance found under PrismLauncher's data dir, or fail if
// there is more than one."
type instanceArg struct {
	Instance string `json:"instance,omitempty" jsonschema:"Prism instance name; optional if there is exactly one instance"`
}

func (a instanceArg) resolve() (*prism.Instance, error) {
	return prism.Resolve(a.Instance)
}

// ---- find_recipe -----------------------------------------------------------

type findRecipeIn struct {
	instanceArg
	Query string `json:"query" jsonschema:"item id (e.g. create:andesite_alloy) or substring to match against recipe outputs"`
	Limit int    `json:"limit,omitempty" jsonschema:"max results (default 25)"`
}

type findRecipeOut struct {
	Matches []recipes.Match `json:"matches"`
}

func findRecipe(ctx context.Context, _ *mcp.CallToolRequest, in findRecipeIn) (*mcp.CallToolResult, findRecipeOut, error) {
	inst, err := in.resolve()
	if err != nil {
		return nil, findRecipeOut{}, err
	}
	limit := in.Limit
	if limit <= 0 {
		limit = 25
	}
	matches, err := recipes.Find(ctx, inst, in.Query, limit)
	if err != nil {
		return nil, findRecipeOut{}, err
	}
	return nil, findRecipeOut{Matches: matches}, nil
}

// ---- tail_chat -------------------------------------------------------------

type tailChatIn struct {
	instanceArg
	Lines int `json:"lines,omitempty" jsonschema:"how many trailing lines to return (default 100)"`
}

type tailChatOut struct {
	Lines []logs.Line `json:"lines"`
}

func tailChat(ctx context.Context, _ *mcp.CallToolRequest, in tailChatIn) (*mcp.CallToolResult, tailChatOut, error) {
	inst, err := in.resolve()
	if err != nil {
		return nil, tailChatOut{}, err
	}
	n := in.Lines
	if n <= 0 {
		n = 100
	}
	lines, err := logs.Tail(ctx, inst, n)
	if err != nil {
		return nil, tailChatOut{}, err
	}
	return nil, tailChatOut{Lines: lines}, nil
}

// ---- list_screenshots ------------------------------------------------------

type listScreenshotsIn struct {
	instanceArg
	Limit int `json:"limit,omitempty" jsonschema:"max entries (default 25, newest first)"`
}

type listScreenshotsOut struct {
	Screenshots []screenshots.Screenshot `json:"screenshots"`
}

func listScreenshots(ctx context.Context, _ *mcp.CallToolRequest, in listScreenshotsIn) (*mcp.CallToolResult, listScreenshotsOut, error) {
	inst, err := in.resolve()
	if err != nil {
		return nil, listScreenshotsOut{}, err
	}
	limit := in.Limit
	if limit <= 0 {
		limit = 25
	}
	shots, err := screenshots.List(inst, limit)
	if err != nil {
		return nil, listScreenshotsOut{}, err
	}
	return nil, listScreenshotsOut{Screenshots: shots}, nil
}

// ---- list_instances --------------------------------------------------------

type listInstancesOut struct {
	Instances []string `json:"instances"`
}

func listInstances(_ context.Context, _ *mcp.CallToolRequest, _ struct{}) (*mcp.CallToolResult, listInstancesOut, error) {
	names, err := prism.ListInstances()
	if err != nil {
		return nil, listInstancesOut{}, err
	}
	return nil, listInstancesOut{Instances: names}, nil
}

// ----------------------------------------------------------------------------

func main() {
	// MCP uses stdout for JSON-RPC — send everything else to stderr.
	log.SetOutput(os.Stderr)
	log.SetFlags(log.LstdFlags | log.Lmicroseconds)

	server := mcp.NewServer(&mcp.Implementation{
		Name:    "mcp-minecraft",
		Version: version,
	}, nil)

	mcp.AddTool(server, &mcp.Tool{
		Name:        "list_instances",
		Description: "list Prism Launcher instances found on disk",
	}, listInstances)

	mcp.AddTool(server, &mcp.Tool{
		Name:        "find_recipe",
		Description: "search recipes indexed from every mod jar in the instance's mods/ folder",
	}, findRecipe)

	mcp.AddTool(server, &mcp.Tool{
		Name:        "tail_chat",
		Description: "return the last N lines of the instance's client log (chat + system)",
	}, tailChat)

	mcp.AddTool(server, &mcp.Tool{
		Name:        "list_screenshots",
		Description: "list recent screenshot files from the instance",
	}, listScreenshots)

	if err := server.Run(context.Background(), &mcp.StdioTransport{}); err != nil {
		log.Fatal(err)
	}
}
