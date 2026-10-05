import React from "react"
import { createRoot } from "react-dom/client"
import { App } from "~/app/App"

const container = document.getElementById("root")

if (!container) {
  throw new Error("Expected #root in the page before mounting the app")
}

createRoot(container).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
