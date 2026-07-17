// Minimal synchronous MCP server core: JSON-RPC 2.0 over Streamable HTTP
// (plain-JSON POST responses, no SSE). Hand-rolled because the official
// SDK is Promise-saturated and Rhino has no event loop; the server side
// of MCP is small enough that sync dispatch covers it.

import { TOOLS } from "./tools";

const PROTOCOL_VERSION = "2025-03-26";
const SERVER_INFO = { name: "kubejs-mcp", version: "0.1.0" };

interface RpcMessage {
  jsonrpc?: string;
  id?: unknown;
  method?: string;
  params?: any;
}

function result(id: unknown, payload: unknown): object {
  return { jsonrpc: "2.0", id, result: payload };
}

function rpcError(id: unknown, code: number, message: string): object {
  return { jsonrpc: "2.0", id, error: { code, message } };
}

/**
 * Run fn on the game thread and block until it completes. tinyserver
 * handlers run on their own thread; world access must happen on the
 * server thread. executeBlocking runs inline if already on it.
 */
function runOnGameThread(fn: () => unknown): unknown {
  let out: unknown;
  let threw = false;
  let err: unknown;
  Utils.server.executeBlocking(() => {
    try {
      out = fn();
    } catch (e) {
      threw = true;
      err = e;
    }
  });
  if (threw) {
    throw err;
  }
  return out;
}

function toolList(): object[] {
  const list: object[] = [];
  for (const name of Object.keys(TOOLS)) {
    const tool = TOOLS[name];
    list.push({
      name,
      description: tool.description,
      inputSchema: tool.inputSchema,
    });
  }
  return list;
}

function callTool(params: any): object {
  const name = params != null ? String(params.name) : "";
  const tool = TOOLS[name];
  if (tool == null) {
    return {
      content: [{ type: "text", text: `unknown tool: ${name}` }],
      isError: true,
    };
  }
  const args = params != null && params.arguments != null ? params.arguments : {};
  try {
    const raw = tool.onGameThread
      ? runOnGameThread(() => tool.run(args))
      : tool.run(args);
    const text = typeof raw === "string" ? raw : JSON.stringify(raw, null, 2);
    return { content: [{ type: "text", text }] };
  } catch (e) {
    return {
      content: [{ type: "text", text: `tool ${name} failed: ${e}` }],
      isError: true,
    };
  }
}

/** Handle one JSON-RPC message. Returns null for notifications (no reply). */
function handleMessage(msg: RpcMessage): object | null {
  if (msg == null || msg.jsonrpc !== "2.0" || typeof msg.method !== "string") {
    return rpcError(msg != null && msg.id != null ? msg.id : null, -32600, "invalid request");
  }
  const id = msg.id;
  const isNotification = id === undefined || id === null;
  try {
    switch (msg.method) {
      case "initialize":
        return result(id, {
          protocolVersion:
            msg.params != null && typeof msg.params.protocolVersion === "string"
              ? msg.params.protocolVersion
              : PROTOCOL_VERSION,
          capabilities: { tools: {} },
          serverInfo: SERVER_INFO,
        });
      case "ping":
        return result(id, {});
      case "tools/list":
        return result(id, { tools: toolList() });
      case "tools/call":
        return result(id, callTool(msg.params));
      default:
        // Silently accept all notifications (incl. notifications/initialized).
        if (isNotification) {
          return null;
        }
        return rpcError(id, -32601, `method not found: ${msg.method}`);
    }
  } catch (e) {
    if (isNotification) {
      return null;
    }
    return rpcError(id, -32603, `internal error: ${e}`);
  }
}

/**
 * Handle a Streamable-HTTP POST body (single message or batch).
 * Returns the JSON-serializable response payload, or null when there is
 * nothing to send (notifications only → HTTP 202).
 */
export function handlePost(bodyText: string): object | object[] | null {
  let msg: unknown;
  try {
    msg = JSON.parse(bodyText);
  } catch (e) {
    return rpcError(null, -32700, "parse error");
  }
  if (Array.isArray(msg)) {
    const responses: object[] = [];
    for (const m of msg) {
      const r = handleMessage(m as RpcMessage);
      if (r != null) {
        responses.push(r);
      }
    }
    return responses.length > 0 ? responses : null;
  }
  return handleMessage(msg as RpcMessage);
}
