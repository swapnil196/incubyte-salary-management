import { screen, waitFor } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { afterEach, vi } from "vitest"
import { renderPage, stubApi } from "~/test/render"
import { EmployeePage } from "./EmployeePage"

vi.mock("react-router-dom", async () => {
  const actual = await vi.importActual<typeof import("react-router-dom")>("react-router-dom")
  return { ...actual, useParams: () => ({ id: "7" }) }
})

const reference = {
  data: {
    departments: [],
    job_levels: [],
    countries: [],
    change_reasons: ["merit", "promotion"],
    currencies: ["EUR", "USD"],
    base_currency: "EUR",
  },
}

const detail = (overrides = {}) => ({
  data: {
    id: 7,
    employee_number: "ACME-00007",
    first_name: "Ada",
    last_name: "Lovelace",
    full_name: "Ada Lovelace",
    email: "ada@acme.example",
    country_code: "DE",
    gender: "female",
    department: { id: 1, name: "Engineering" },
    job_level: { id: 1, name: "Senior", rank: 4 },
    status: "active",
    hired_on: "2023-01-01",
    terminated_on: null,
    current_salary: {
      id: 3,
      amount_cents: 6_600_000,
      currency: "EUR",
      base_amount_cents: 6_600_000,
      base_currency: "EUR",
      fx_rate: "1.0",
      fx_rate_date: "2026-01-01",
      effective_from: "2025-01-01",
      effective_to: null,
      change_reason: "promotion",
      current: true,
      change_from_previous: 20.0,
    },
    band: {
      min_cents: 5_000_000,
      mid_cents: 6_000_000,
      max_cents: 7_000_000,
      currency: "EUR",
      compa_ratio: 1.1,
      status: "within_band",
    },
    salary_history: [
      {
        id: 3,
        amount_cents: 6_600_000,
        currency: "EUR",
        base_amount_cents: 6_600_000,
        base_currency: "EUR",
        fx_rate: "1.0",
        fx_rate_date: "2026-01-01",
        effective_from: "2025-01-01",
        effective_to: null,
        change_reason: "promotion",
        current: true,
        change_from_previous: 20.0,
      },
      {
        id: 1,
        amount_cents: 5_500_000,
        currency: "EUR",
        base_amount_cents: 5_500_000,
        base_currency: "EUR",
        fx_rate: "1.0",
        fx_rate_date: "2026-01-01",
        effective_from: "2023-01-01",
        effective_to: "2025-01-01",
        change_reason: "hire",
        current: false,
        change_from_previous: null,
      },
    ],
    ...overrides,
  },
})

afterEach(() => vi.unstubAllGlobals())

describe("EmployeePage", () => {
  it("shows the profile, the current salary and the band position", async () => {
    stubApi({ "/reference": reference, "/employees/7": detail() })

    renderPage(<EmployeePage />)

    expect(await screen.findByText("Ada Lovelace")).toBeInTheDocument()
    // Appears twice by design: once on the current-salary card and once as the
    // most recent entry in the history.
    expect(screen.getAllByText("€66,000")).toHaveLength(2)
    expect(screen.getByText("1.10")).toBeInTheDocument()
    expect(screen.getByText("In band")).toBeInTheDocument()
  })

  it("lists the salary history newest first, with the rise on each change", async () => {
    stubApi({ "/reference": reference, "/employees/7": detail() })

    renderPage(<EmployeePage />)

    await screen.findByText("Ada Lovelace")

    expect(screen.getByText("+20.0%")).toBeInTheDocument()
    expect(screen.getByText(/Promotion · 1 Jan 2025 to present/)).toBeInTheDocument()
    expect(screen.getByText(/Hire · 1 Jan 2023 to 1 Jan 2025/)).toBeInTheDocument()
  })

  it("shows the rate used when the salary is not in the base currency", async () => {
    stubApi({
      "/reference": reference,
      "/employees/7": detail({
        current_salary: {
          ...detail().data.current_salary,
          currency: "USD",
          base_amount_cents: 6_072_000,
          fx_rate: "0.92",
        },
      }),
    })

    renderPage(<EmployeePage />)

    expect(await screen.findByText(/€60,720 at 0.92 on 1 Jan 2026/)).toBeInTheDocument()
  })

  it("will not offer a pay change for someone who has left" , async () => {
    stubApi({
      "/reference": reference,
      "/employees/7": detail({ status: "terminated", terminated_on: "2025-06-30" }),
    })

    renderPage(<EmployeePage />)

    expect(await screen.findByRole("button", { name: "Record pay change" })).toBeDisabled()
  })

  it("submits a pay change as a string amount, never a number", async () => {
    const fetchMock = stubApi({
      "/reference": reference,
      "/employees/7/salary_records": { data: {} },
      "/employees/7": detail(),
    })
    const user = userEvent.setup()

    renderPage(<EmployeePage />)
    await screen.findByText("Ada Lovelace")

    await user.click(screen.getByRole("button", { name: "Record pay change" }))
    await user.type(await screen.findByPlaceholderText("70000"), "72000")
    await user.click(screen.getByRole("button", { name: "Record change" }))

    await waitFor(() => {
      const call = fetchMock.mock.calls.find((c) => String(c[0]).includes("salary_records"))
      expect(call).toBeDefined()
      const body = JSON.parse((call![1] as RequestInit).body as string)
      // A string, because the backend refuses Floats for money and parsing to
      // one here would defeat that at the boundary.
      expect(body.salary_record.amount).toBe("72000")
      expect(typeof body.salary_record.amount).toBe("string")
    })
  })

  it("shows the server's reason when a change is rejected" , async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async (input: RequestInfo | URL) => {
        const url = String(input)
        if (url.includes("salary_records")) {
          return {
            ok: false,
            status: 422,
            json: async () => ({
              error: { message: "effective date cannot be in the future" },
            }),
          } as Response
        }
        if (url.includes("/reference")) {
          return { ok: true, status: 200, json: async () => reference } as Response
        }
        return { ok: true, status: 200, json: async () => detail() } as Response
      }),
    )
    const user = userEvent.setup()

    renderPage(<EmployeePage />)
    await screen.findByText("Ada Lovelace")

    await user.click(screen.getByRole("button", { name: "Record pay change" }))
    await user.type(await screen.findByPlaceholderText("70000"), "72000")
    await user.click(screen.getByRole("button", { name: "Record change" }))

    expect(await screen.findByText("effective date cannot be in the future")).toBeInTheDocument()
  })
})
