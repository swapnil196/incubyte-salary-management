import { defineConfig } from "vite"
import RubyPlugin from "vite-plugin-ruby"
import react from "@vitejs/plugin-react"
import path from "node:path"

export default defineConfig({
  plugins: [RubyPlugin(), react()],
  resolve: {
    alias: { "~": path.resolve(import.meta.dirname, "app/frontend") },
  },
})
