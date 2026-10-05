import { defineConfig } from "vitest/config"
import react from "@vitejs/plugin-react"
import path from "node:path"

// Deliberately does not load vite-plugin-ruby: that plugin expects a Rails
// server and asset manifest, neither of which exist in a unit test run.
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: { "~": path.resolve(import.meta.dirname, "app/frontend") },
  },
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./app/frontend/test/setup.ts"],
    include: ["app/frontend/**/*.test.{ts,tsx}"],
  },
})
