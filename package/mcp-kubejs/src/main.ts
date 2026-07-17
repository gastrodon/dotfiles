// Entry point: boots a tinyserver HTTP instance inside the game JVM and
// serves MCP Streamable-HTTP on POST /mcp. tinyserver is jarjar'd inside
// the KubeJS jar and default-allowed by the class filter, which is what
// makes serving HTTP from server_scripts possible at all.

import { handlePost } from "./mcp";

const PORT = 25580;
const GLOBAL_KEY = "kubejs_mcp_http_server";

const HTTPServer = Java.loadClass("dev.latvian.apps.tinyserver.HTTPServer");
const HTTPRequest = Java.loadClass("dev.latvian.apps.tinyserver.http.HTTPRequest");
const HTTPResponse = Java.loadClass(
  "dev.latvian.apps.tinyserver.http.response.HTTPResponse",
);

// /kubejs reload server_scripts re-runs this bundle in a fresh scope, but
// the old tinyserver instance (and its bound port) survives in the JVM.
// Stop it via the handle stashed in KubeJS `global` before rebinding.
const stale = global[GLOBAL_KEY];
if (stale != null) {
  try {
    (stale as any).stop();
    console.info("kubejs-mcp: stopped stale HTTP server before rebind");
  } catch (e) {
    console.warn(`kubejs-mcp: failed to stop stale HTTP server: ${e}`);
  }
  global[GLOBAL_KEY] = null;
}

const httpServer = new HTTPServer(() => new HTTPRequest());
httpServer.setServerName("kubejs-mcp");
httpServer.setAddress("0.0.0.0");
httpServer.setPort(PORT);
httpServer.setDaemon(true);

// Single stateless endpoint. GET (SSE stream) and DELETE (session teardown)
// are deliberately unregistered — tinyserver 405s them, which spec-compliant
// clients treat as "server doesn't support that feature".
httpServer.post("/mcp", (req: any) => {
  const payload = handlePost(String(req.mainBody().text()));
  if (payload == null) {
    // Notifications only — nothing to send back.
    return HTTPResponse.accepted();
  }
  return HTTPResponse.ok().json(JSON.stringify(payload));
});

httpServer.start();
global[GLOBAL_KEY] = httpServer;
console.info(`kubejs-mcp: MCP server listening on 0.0.0.0:${PORT} (POST /mcp)`);
