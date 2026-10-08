import { screen, waitFor, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { afterEach, vi } from "vitest"
import { renderPage, stubApi } from "~/test/render"
import { DirectoryPage } from "./DirectoryPage"

const reference = {
  data: {
    departments: [{ id: 1, name: "Engineering" }],
    job_levels: [{ id: 1, name: "Senior", rank: 4 }],
    countries: ["DE", "US"],
    change_reasons: ["merit"],
    currencies: ["EUR"],
    base_currency: "EUR",
  },
}

const employeeRow = {
  id: 7,
  employee_number: "ACME-00007",
  full_name: "Ada Lovelace",
  email: "ada@acme.example",
  country_code: "DE",
  department: "Engineering",
  job_level: "Senior",
  status: "active",
  hired_on: "2023-01-01",
  terminated_on: null,
  salary: {
    amount_cents: 6_600_000,
    currency: "EUR",
    base_amount_cents: 6_600_000,
    base_currency: "EUR",
    effective_from: "2025-01-01",
  },
  band: {
    min_cents: 5_000_000,
    mid_cents: 6_000_000,
    max_cents: 7_000_000,
    currency: "EUR",
    compa_ratio: 1.1,
    status: "within_band",
  },
}

const page = (overrides = {}) => ({
  data: [employeeRow],
  meta: {
    page: 1,
    per_page: 25,
    total_count: 1,
    total_pages: 1,
    sort: "name",
    direction: "asc",
    status: "active",
    ...overrides,
  },
})

afterEach(() => vi.unstubAllGlobals())

describe("DirectoryPage", () => {
  it("renders an employee row with salary, compa-ratio and band status", async () => {
    stubApi({ "/reference": reference, "/employees": page() })

    renderPage(<DirectoryPage />)

    const row = await screen.findByRole("row", { name: /Ada Lovelace/ })

    expect(within(row).getByText("Engineering")).toBeInTheDocument()
    expect(within(row).getByText("€66,000")).toBeInTheDocument()
    expect(within(row).getByText("1.10")).toBeInTheDocument()
    expect(within(row).getByText("In band")).toBeInTheDocument()
  })

  it("shows the headcount returned by the server, not the number of rows on screen", async () => {
    stubApi({ "/reference": reference, "/employees": page({ total_count: 9220, total_pages: 369 }) })

    renderPage(<DirectoryPage />)

    expect(await screen.findByText("9,220 employees")).toBeInTheDocument()
  })

  it("shows the local amount and the base-currency equivalent for a foreign salary", async () => {
    stubApi({
      "/reference": reference,
      "/employees": {
        ...page(),
        data: [
          {
            ...employeeRow,
            salary: { ...employeeRow.salary, currency: "USD", base_amount_cents: 6_072_000 },
          },
        ],
      },
    })

    renderPage(<DirectoryPage />)

    const row = await screen.findByRole("row", { name: /Ada Lovelace/ })

    expect(within(row).getByText("US$66,000")).toBeInTheDocument()
    expect(within(row).getByText("€60,720")).toBeInTheDocument()
  })

  it("sends the search term to the server after debouncing", async () => {
    const fetchMock = stubApi({ "/reference": reference, "/employees": page() })
    const user = userEvent.setup()

    renderPage(<DirectoryPage />)
    await screen.findByRole("row", { name: /Ada Lovelace/ })

    await user.type(screen.getByLabelText("Search"), "lovelace")

    await waitFor(() => {
      const urls = fetchMock.mock.calls.map((call) => String(call[0]))
      expect(urls.some((url) => url.includes("q=lovelace"))).toBe(true)
    })

    // Debounced: eight keystrokes must not become eight requests.
    const searchRequests = fetchMock.mock.calls
      .map((call) => String(call[0]))
      .filter((url) => url.includes("q="))
    expect(searchRequests.length).toBeLessThan(4)
  })

  it("asks the server to sort when a column heading is clicked", async () => {
    const fetchMock = stubApi({ "/reference": reference, "/employees": page() })
    const user = userEvent.setup()

    renderPage(<DirectoryPage />)
    await screen.findByRole("row", { name: /Ada Lovelace/ })

    await user.click(screen.getByRole("button", { name: /Salary/ }))

    await waitFor(() => {
      const urls = fetchMock.mock.calls.map((call) => String(call[0]))
      expect(urls.some((url) => url.includes("sort=salary"))).toBe(true)
    })
  })

  it("points the export link at the same filters that are on screen", async () => {
    stubApi({ "/reference": reference, "/employees": page() })

    renderPage(<DirectoryPage />, { route: "/?country_code=DE&status=all" })

    const link = await screen.findByRole("link", { name: "Export CSV" })

    expect(link).toHaveAttribute("href", expect.stringContaining("country_code=DE"))
    expect(link).toHaveAttribute("href", expect.stringContaining("status=all"))
  })

  it("says so when nothing matches, instead of showing an empty table", async () => {
    stubApi({
      "/reference": reference,
      "/employees": { data: [], meta: { ...page().meta, total_count: 0, total_pages: 0 } },
    })

    renderPage(<DirectoryPage />)

    expect(await screen.findByText("No employees match these filters.")).toBeInTheDocument()
  })

  it("surfaces a failed request rather than rendering an empty directory", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => ({
        ok: false,
        status: 500,
        json: async () => ({ error: { message: "Database unavailable" } }),
      })),
    )

    renderPage(<DirectoryPage />)

    expect(await screen.findByText("Could not load this data")).toBeInTheDocument()
    expect(screen.getByText("Database unavailable")).toBeInTheDocument()
  })
})
