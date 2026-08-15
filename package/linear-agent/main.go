// linear-agent: webhook receiver that bridges Linear agent sessions to Nomad.
//
// On a Linear AgentSessionEvent it (1) verifies the HMAC signature, (2) returns
// 200 within Linear's 5s budget, then asynchronously (3) posts a `thought`
// activity to acknowledge the session within the 10s budget and (4) dispatches
// a parameterized Nomad batch job to run the actual agent (pi) in isolation.
package main

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

const linearGraphQL = "https://api.linear.app/graphql"

type config struct {
	listenAddr    string
	webhookSecret []byte
	appToken      string
	nomadAddr     string
	nomadToken    string
	nomadJob      string
}

func loadConfig() config {
	get := func(k, def string) string {
		if v := os.Getenv(k); v != "" {
			return v
		}
		return def
	}
	// Linear creds are optional at startup: the process stays up (and /health
	// serves) before the Linear app exists. Webhooks are rejected until the
	// signing secret is set; see handleWebhook.
	return config{
		listenAddr:    get("LISTEN_ADDR", ":3456"),
		webhookSecret: []byte(os.Getenv("LINEAR_WEBHOOK_SECRET")),
		appToken:      os.Getenv("LINEAR_APP_TOKEN"),
		nomadAddr:     get("NOMAD_ADDR", "http://127.0.0.1:4646"),
		nomadToken:    os.Getenv("NOMAD_TOKEN"),
		nomadJob:      get("NOMAD_JOB", "pi-agent"),
	}
}

// agentSessionEvent is the subset of the Linear webhook we act on.
type agentSessionEvent struct {
	Type         string `json:"type"`
	Action       string `json:"action"`
	AgentSession struct {
		ID string `json:"id"`
	} `json:"agentSession"`
}

func main() {
	cfg := loadConfig()
	c := &client{http: &http.Client{Timeout: 10 * time.Second}, cfg: cfg}

	mux := http.NewServeMux()
	mux.HandleFunc("/webhook", c.handleWebhook)
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		io.WriteString(w, "ok\n")
	})

	log.Printf("linear-agent listening on %s (nomad job %q)", cfg.listenAddr, cfg.nomadJob)
	srv := &http.Server{Addr: cfg.listenAddr, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}

type client struct {
	http *http.Client
	cfg  config
}

func (c *client) handleWebhook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	// Fail closed until the Linear signing secret is configured — an empty-key
	// HMAC would be forgeable, so reject rather than verify against "".
	if len(c.cfg.webhookSecret) == 0 {
		http.Error(w, "receiver not configured", http.StatusServiceUnavailable)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, "read error", http.StatusBadRequest)
		return
	}
	if !c.verify(r.Header.Get("Linear-Signature"), body) {
		http.Error(w, "bad signature", http.StatusUnauthorized)
		return
	}

	var ev agentSessionEvent
	if err := json.Unmarshal(body, &ev); err != nil {
		http.Error(w, "bad json", http.StatusBadRequest)
		return
	}

	// Ack the HTTP request immediately (5s budget); do the slow work off-thread.
	w.WriteHeader(http.StatusOK)

	if ev.Type != "AgentSessionEvent" || ev.AgentSession.ID == "" {
		return
	}
	go c.dispatch(ev, body)
}

// verify checks the Linear-Signature header: hex(HMAC-SHA256(rawBody, secret)).
func (c *client) verify(sig string, body []byte) bool {
	if sig == "" {
		return false
	}
	mac := hmac.New(sha256.New, c.cfg.webhookSecret)
	mac.Write(body)
	want := hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(want), []byte(sig))
}

// dispatch posts the thought ack, then dispatches the Nomad job; on dispatch
// failure it surfaces an error activity back to the session.
func (c *client) dispatch(ev agentSessionEvent, raw []byte) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := c.postActivity(ctx, ev.AgentSession.ID, "thought", "Picking this up — spinning up an agent."); err != nil {
		log.Printf("thought ack failed for session %s: %v", ev.AgentSession.ID, err)
	}

	if err := c.dispatchNomad(ctx, ev, raw); err != nil {
		log.Printf("nomad dispatch failed for session %s: %v", ev.AgentSession.ID, err)
		msg := fmt.Sprintf("Couldn't start the agent job: %v", err)
		if e := c.postActivity(ctx, ev.AgentSession.ID, "error", msg); e != nil {
			log.Printf("error activity failed for session %s: %v", ev.AgentSession.ID, e)
		}
	}
}

// postActivity emits an agent activity (thought | action | response | error).
func (c *client) postActivity(ctx context.Context, sessionID, typ, body string) error {
	if c.cfg.appToken == "" {
		return fmt.Errorf("no LINEAR_APP_TOKEN configured")
	}
	const q = `mutation($input: AgentActivityCreateInput!) {
  agentActivityCreate(input: $input) { success }
}`
	payload := map[string]any{
		"query": q,
		"variables": map[string]any{
			"input": map[string]any{
				"agentSessionId": sessionID,
				"content":        map[string]any{"type": typ, "body": body},
			},
		},
	}
	buf, _ := json.Marshal(payload)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, linearGraphQL, bytes.NewReader(buf))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.cfg.appToken)

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	out, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK || bytes.Contains(out, []byte(`"errors"`)) {
		return fmt.Errorf("graphql %d: %s", resp.StatusCode, out)
	}
	return nil
}

// dispatchNomad kicks the parameterized batch job, passing the raw webhook as
// the dispatch payload and the session id as dispatch meta.
func (c *client) dispatchNomad(ctx context.Context, ev agentSessionEvent, raw []byte) error {
	body := map[string]any{
		"Payload": base64.StdEncoding.EncodeToString(raw),
		"Meta": map[string]string{
			"session_id": ev.AgentSession.ID,
			"action":     ev.Action,
		},
	}
	buf, _ := json.Marshal(body)
	url := c.cfg.nomadAddr + "/v1/job/" + c.cfg.nomadJob + "/dispatch"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(buf))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if c.cfg.nomadToken != "" {
		req.Header.Set("X-Nomad-Token", c.cfg.nomadToken)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	out, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("nomad %d: %s", resp.StatusCode, out)
	}
	return nil
}
