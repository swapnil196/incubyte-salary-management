import { render, screen } from "@testing-library/react"
import { App } from "./App"

describe("App", () => {
  it("mounts the shell and renders the application title", () => {
    render(<App />)

    expect(
      screen.getByRole("heading", { name: /salary management/i }),
    ).toBeInTheDocument()
  })
})
