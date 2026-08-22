import { Player, type Video, type Volume } from "yt-cast-receiver";
import MpvIpc from "./mpvIpc.js";

/**
 * Bridges yt-cast-receiver's abstract Player to a running mpv instance over
 * its JSON IPC socket. yt-cast-receiver only ever hands us a video ID (it
 * deliberately does not resolve stream URLs itself) — we pass a plain watch
 * URL to mpv, which resolves + decrypts + streams it via its built-in
 * yt-dlp hook. All the format-selection / hwdec / BT-sink tuning from
 * EVA-187 lives entirely in how mpv itself is launched, not here.
 */
export default class MpvPlayer extends Player {
  #mpv: MpvIpc;

  constructor(mpv: MpvIpc) {
    super();
    this.#mpv = mpv;
  }

  protected async doPlay(video: Video, position: number): Promise<boolean> {
    const url = `https://www.youtube.com/watch?v=${video.id}`;
    console.log(`[MpvPlayer] play ${url} @ ${position}s (client: ${video.client?.name ?? "unknown"})`);
    try {
      await this.#mpv.loadfile(url, "replace");
      await this.#mpv.setProperty("pause", false);
      if (position > 0) {
        // loadfile is async on mpv's side too; give it a moment to actually
        // have a file loaded before seeking into it.
        setTimeout(() => {
          this.#mpv.command(["seek", position, "absolute"]).catch(() => {});
        }, 1500);
      }
      return true;
    } catch (err) {
      console.error("[MpvPlayer] doPlay failed:", err);
      return false;
    }
  }

  protected async doPause(): Promise<boolean> {
    await this.#mpv.setProperty("pause", true);
    return true;
  }

  protected async doResume(): Promise<boolean> {
    await this.#mpv.setProperty("pause", false);
    return true;
  }

  protected async doStop(): Promise<boolean> {
    await this.#mpv.command(["stop"]);
    return true;
  }

  protected async doSeek(position: number): Promise<boolean> {
    await this.#mpv.command(["seek", position, "absolute"]);
    return true;
  }

  protected async doSetVolume(volume: Volume): Promise<boolean> {
    await this.#mpv.setProperty("volume", volume.level);
    await this.#mpv.setProperty("mute", volume.muted);
    return true;
  }

  protected async doGetVolume(): Promise<Volume> {
    const [level, muted] = await Promise.all([
      this.#mpv.getProperty("volume").catch(() => 100),
      this.#mpv.getProperty("mute").catch(() => false),
    ]);
    return { level: Math.round(Number(level ?? 100)), muted: Boolean(muted) };
  }

  protected async doGetPosition(): Promise<number> {
    const pos = await this.#mpv.getProperty("time-pos").catch(() => 0);
    return Math.floor(Number(pos ?? 0));
  }

  protected async doGetDuration(): Promise<number> {
    const dur = await this.#mpv.getProperty("duration").catch(() => 0);
    return Math.floor(Number(dur ?? 0));
  }
}
