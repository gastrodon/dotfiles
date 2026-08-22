import { createConnection, type Socket } from "node:net";

/**
 * Minimal client for mpv's JSON IPC protocol (--input-ipc-server=<path>).
 * https://mpv.io/manual/master/#json-ipc
 *
 * Hand-rolled instead of pulling in node-mpv or similar: the protocol is a few
 * lines of newline-delimited JSON, and we only need command()/get/set property.
 */

interface Pending {
  resolve: (value: unknown) => void;
  reject: (err: Error) => void;
}

export default class MpvIpc {
  #socketPath: string;
  #socket: Socket | null = null;
  #buffer = "";
  #nextId = 1;
  #pending = new Map<number, Pending>();

  constructor(socketPath: string) {
    this.#socketPath = socketPath;
  }

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      const socket = createConnection(this.#socketPath);
      const onError = (err: Error) => reject(err);
      socket.once("error", onError);
      socket.once("connect", () => {
        socket.off("error", onError);
        this.#socket = socket;
        socket.on("data", (chunk) => this.#onData(chunk));
        socket.on("error", (err) => this.#failAllPending(err));
        socket.on("close", () => {
          this.#socket = null;
          this.#failAllPending(new Error("mpv IPC socket closed"));
        });
        resolve();
      });
    });
  }

  close(): void {
    this.#socket?.end();
    this.#socket = null;
  }

  #failAllPending(err: Error): void {
    for (const { reject } of this.#pending.values()) reject(err);
    this.#pending.clear();
  }

  #onData(chunk: Buffer): void {
    this.#buffer += chunk.toString("utf8");
    let idx: number;
    while ((idx = this.#buffer.indexOf("\n")) >= 0) {
      const line = this.#buffer.slice(0, idx).trim();
      this.#buffer = this.#buffer.slice(idx + 1);
      if (!line) continue;

      let msg: Record<string, unknown>;
      try {
        msg = JSON.parse(line);
      } catch {
        continue;
      }

      // Command replies carry request_id; async events (property-change, etc.)
      // don't and are ignored here — we poll properties instead of subscribing.
      if (typeof msg.request_id === "number" && this.#pending.has(msg.request_id)) {
        const pending = this.#pending.get(msg.request_id)!;
        this.#pending.delete(msg.request_id);
        if (msg.error && msg.error !== "success") {
          pending.reject(new Error(`mpv: ${String(msg.error)}`));
        } else {
          pending.resolve(msg.data);
        }
      }
    }
  }

  command(args: Array<string | number | boolean>): Promise<unknown> {
    if (!this.#socket) return Promise.reject(new Error("mpv IPC not connected"));
    const request_id = this.#nextId++;
    const line = JSON.stringify({ command: args, request_id }) + "\n";
    const socket = this.#socket;
    return new Promise((resolve, reject) => {
      this.#pending.set(request_id, { resolve, reject });
      socket.write(line, (err) => {
        if (err) {
          this.#pending.delete(request_id);
          reject(err);
        }
      });
    });
  }

  getProperty(name: string): Promise<unknown> {
    return this.command(["get_property", name]);
  }

  setProperty(name: string, value: string | number | boolean): Promise<unknown> {
    return this.command(["set_property", name, value]);
  }

  loadfile(url: string, mode: "replace" | "append" | "append-play" = "replace"): Promise<unknown> {
    return this.command(["loadfile", url, mode]);
  }
}
