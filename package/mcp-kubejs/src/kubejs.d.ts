// Ambient declarations for the KubeJS/Rhino runtime.
// Only the surface this package actually touches — full game typings
// come from a ProbeJS dump later (see README.md).

/** KubeJS Java interop. loadClass throws if the class filter denies. */
declare const Java: {
  loadClass(name: string): any;
  tryLoadClass(name: string): any | null;
};

/** KubeJS cross-reload persistent storage. Survives /kubejs reload. */
declare const global: Record<string, unknown>;

/** KubeJS logger — writes to logs/kubejs/server.log, not latest.log. */
declare const console: {
  info(message: unknown): void;
  warn(message: unknown): void;
  error(message: unknown): void;
};

/** KubeJS Utils binding. .server is the running MinecraftServer. */
declare const Utils: {
  readonly server: any;
};
