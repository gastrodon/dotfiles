// Package logs tails the Minecraft client log at <mc>/logs/latest.log.
package logs

import (
	"bufio"
	"context"
	"os"

	"github.com/gastrodon/mcp-minecraft/internal/prism"
)

// Line is one log line.
type Line struct {
	Text string `json:"text"`
}

// Tail returns the last n lines of latest.log.
func Tail(_ context.Context, inst *prism.Instance, n int) ([]Line, error) {
	f, err := os.Open(inst.Path("logs", "latest.log"))
	if err != nil {
		return nil, err
	}
	defer f.Close()

	// Simple ring buffer over lines. Latest.log for a running instance
	// stays modest in size; if needed later swap for a reverse read.
	ring := make([]string, n)
	head, filled := 0, 0
	s := bufio.NewScanner(f)
	s.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for s.Scan() {
		ring[head] = s.Text()
		head = (head + 1) % n
		if filled < n {
			filled++
		}
	}
	if err := s.Err(); err != nil {
		return nil, err
	}
	out := make([]Line, 0, filled)
	start := head - filled
	if start < 0 {
		start += n
	}
	for i := 0; i < filled; i++ {
		out = append(out, Line{Text: ring[(start+i)%n]})
	}
	return out, nil
}
