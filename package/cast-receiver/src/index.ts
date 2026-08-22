#!/usr/bin/env node
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import YouTubeCastReceiver from "yt-cast-receiver";
import MpvIpc from "./mpvIpc.js";
import MpvPlayer from "./MpvPlayer.js";

// --- Config (env, all optional) ---------------------------------------
const SOCKET_PATH = process.env.MPV_SOCKET || "/tmp/mpv-cast-prototype.sock";
const DEVICE_NAME = process.env.DEVICE_NAME || "Cast Receiver";
const DIAL_PORT = Number(process.env.DIAL_PORT || 4000); // default lib port (3000) avoided in case something else owns it
const AUDIO_ONLY = process.env.AUDIO_ONLY !== "0"; // default on: no window needed to prove the control plane works
const MPV_BIN = process.env.MPV_BIN || "mpv";
const YTDLP_BIN = process.env.YTDLP_BIN; // if set, pin mpv's ytdl_hook to this path instead of a PATH lookup

function waitForSocket(path: string, timeoutMs = 8000): Promise<void> {
  return new Promise((resolve, reject) => {
    const start = Date.now();
    const tick = () => {
      if (existsSync(path)) return resolve();
      if (Date.now() - start > timeoutMs) return reject(new Error(`${path} did not appear within ${timeoutMs}ms`));
      setTimeout(tick, 100);
    };
    tick();
  });
}

async function main() {
  console.log(`[proto] launching mpv (${AUDIO_ONLY ? "audio-only" : "with video window"})...`);
  const mpvArgs = [
    "--idle=yes",
    `--input-ipc-server=${SOCKET_PATH}`,
    "--ytdl-format=bv*[vcodec^=avc1]+ba/b",
    "--no-terminal",
  ];
  if (YTDLP_BIN) mpvArgs.push(`--script-opts=ytdl_hook-ytdl_path=${YTDLP_BIN}`);
  if (AUDIO_ONLY) mpvArgs.push("--no-video");

  const mpvProc = spawn(MPV_BIN, mpvArgs, { stdio: "inherit" });
  mpvProc.on("exit", (code) => console.log(`[proto] mpv exited (code ${code})`));
  mpvProc.on("error", (err) => {
    console.error(`[proto] failed to launch mpv (${MPV_BIN}):`, err.message);
    console.error("[proto] hint: nix shell nixpkgs#mpv nixpkgs#yt-dlp, or set MPV_BIN");
    process.exit(1);
  });

  await waitForSocket(SOCKET_PATH);
  const mpv = new MpvIpc(SOCKET_PATH);
  await mpv.connect();
  console.log("[proto] connected to mpv IPC socket");

  const player = new MpvPlayer(mpv);
  const receiver = new YouTubeCastReceiver(player, {
    dial: { port: DIAL_PORT },
    device: { name: DEVICE_NAME },
  });

  receiver.on("senderConnect", (sender) => {
    console.log(`[proto] sender connected: ${sender.name} (${sender.client?.name ?? "unknown client"})`);
  });
  receiver.on("senderDisconnect", (sender, implicit) => {
    console.log(`[proto] sender disconnected: ${sender.name}${implicit ? " (implicit)" : ""}`);
  });
  receiver.on("error", (err) => console.error("[proto] receiver error:", err));
  receiver.on("terminate", (err) => console.error("[proto] receiver terminated:", err));

  player.queue.on("videoAdded", () => console.log("[proto] queue: video added"));
  player.queue.on("videoSelected", () => console.log("[proto] queue: video selected"));
  player.queue.on("videoRemoved", () => console.log("[proto] queue: video removed"));
  player.queue.on("playlistCleared", () => console.log("[proto] queue: cleared"));

  await receiver.start();
  console.log(`[proto] DIAL server listening on :${DIAL_PORT}`);
  console.log(`[proto] Open YouTube or YouTube Music on your phone (same LAN as stone), tap Cast, look for "${DEVICE_NAME}"`);

  const shutdown = async () => {
    console.log("\n[proto] shutting down...");
    await receiver.stop().catch(() => {});
    mpvProc.kill();
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

main().catch((err) => {
  console.error("[proto] fatal:", err);
  process.exit(1);
});
