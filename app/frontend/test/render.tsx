import { MantineProvider } from "@mantine/core"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { render } from "@testing-library/react"
import type { ReactElement } from "react"
import { MemoryRouter } from "react-router-dom"

// Every page needs the same three providers. Retries are off so a deliberate
// failure in a test surfaces immediately instead of after three attempts.
export function renderPage(ui: ReactElement, { route = "/" } = {}) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false, gcTime: 0 } },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MantineProvider>
        <MemoryRouter initialEntries={[route]}>{ui}</MemoryRouter>
      </MantineProvider>
    </QueryClientProvider>,
  )
}

type Handler = (url: string) => unknown

// Routes fetch calls by path fragment. Anything unmatched throws, so a test
// cannot silently pass against a request nobody stubbed.
export function stubApi(routes: Record<string, Handler | unknown>) {
  const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
    const url = String(input)
    const match = Object.keys(routes).find((fragment) => url.includes(fragment))

    if (!match) throw new Error(`Unstubbed request: ${url}`)

    const handler = routes[match]
    const body = typeof handler === "function" ? (handler as Handler)(url) : handler

    return { ok: true, status: 200, json: async () => body } as Response
  })

  vi.stubGlobal("fetch", fetchMock)
  return fetchMock
}
