import { readFileSync } from "node:fs";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

const pkg = JSON.parse(readFileSync(new URL("./package.json", import.meta.url), "utf-8")) as { version: string };

export default defineConfig({
  plugins: [react()],
  // Relative base so the build works from any sub-path (GitHub Pages, Netlify, a phone-hosted folder…).
  base: "./",
  define: {
    __APP_VERSION__: JSON.stringify(pkg.version),
  },
  server: {
    port: 5173,
    // Listen on the LAN so an Android phone on the same Wi-Fi can open the dev server.
    host: true,
  },
  preview: {
    port: 4173,
    host: true,
  },
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
  },
});
