import { screen, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { afterEach, vi } from "vitest"
import { renderPage, stubApi } from "~/test/render"
import { InsightsPage } from "./InsightsPage"

const insights = (overrides = {}) => ({
  data: {
    summary: {
      headcount: 9220,
      annual_payroll_cents: 65_745_539_300,
      currency: "EUR",
      median_cents: 6_000_000,
      p25_cents: 3_938_900,
      p75_cents: 9_040_200,
    },
    by_country: [
      { key: "DE", headcount: 2400, suppressed: false, median_cents: 5_800_000, p25_cents: 4_000_000, p75_cents: 8_000_000 },
      { key: "JP", headcount: 3, suppressed: true },
    ],
    by_department: [
      { key: "Engineering", headcount: 3000, suppressed: false, median_cents: 6_500_000, p25_cents: 4_500_000, p75_cents: 9_000_000 },
    ],
    by_level: [
      { key: "Junior", headcount: 1289, suppressed: false, median_cents: 3_607_900, p25_cents: 3_000_000, p75_cents: 4_200_000 },
      { key: "Senior", headcount: 2177, suppressed: false, median_cents: 6_671_900, p25_cents: 5_800_000, p75_cents: 7_600_000 },
    ],
    band_status: { below_minimum: 524, within_band: 8236, above_maximum: 460 },
    pay_equity: [
      { job_level: "Senior", country_code: "DE", gender: "male", headcount: 92, suppressed: false, median_cents: 15_186_400, p25_cents: 1, p75_cents: 2, difference_from_reference_pct: 0 },
      { job_level: "Senior", country_code: "DE", gender: "female", headcount: 84, suppressed: false, median_cents: 14_734_200, p25_cents: 1, p75_cents: 2, difference_from_reference_pct: -2.5 },
      { job_level: "Senior", country_code: "DE", gender: "non_binary", headcount: 2, suppressed: true, difference_from_reference_pct: null },
    ],
    meta: { base_currency: "EUR", minimum_group_size: 5 },
    ...overrides,
  },
})

afterEach(() => vi.unstubAllGlobals())

describe("InsightsPage", () => {
  it("shows the headline figures", async () => {
    stubApi({ "/insights": insights() })

    renderPage(<InsightsPage />)

    expect(await screen.findByText("€657.5M")).toBeInTheDocument()
    expect(screen.getByText("9,220")).toBeInTheDocument()
    expect(screen.getByText("€60,000")).toBeInTheDocument()
  })

  it("labels the median so nobody reads it as an average", async () => {
    stubApi({ "/insights": insights() })

    renderPage(<InsightsPage />)

    expect(await screen.findByText("Half the organisation earns less than this")).toBeInTheDocument()
  })

  it("counts who sits outside their pay band, with labels not just colour", async () => {
    stubApi({ "/insights": insights() })

    renderPage(<InsightsPage />)

    expect(await screen.findByText("524")).toBeInTheDocument()
    expect(screen.getByText("Below minimum")).toBeInTheDocument()
    expect(screen.getByText("Above maximum")).toBeInTheDocument()
  })

  it("shows distributions by level and can switch dimension", async () => {
    stubApi({ "/insights": insights() })
    const user = userEvent.setup()

    renderPage(<InsightsPage />)

    expect(await screen.findByText("Junior")).toBeInTheDocument()

    await user.click(screen.getByRole("tab", { name: "By country" }))

    // Scoped to the panel: "DE" also appears in the pay equity table below.
    const panel = await screen.findByRole("tabpanel")
    expect(within(panel).getByText("DE")).toBeInTheDocument()
    expect(within(panel).getByText("2,400")).toBeInTheDocument()
  })

  it("explains a withheld group rather than rendering a blank row", async () => {
    stubApi({ "/insights": insights() })
    const user = userEvent.setup()

    renderPage(<InsightsPage />)
    await screen.findByText("Junior")
    await user.click(screen.getByRole("tab", { name: "By country" }))

    const row = await screen.findByRole("row", { name: /JP/ })

    expect(within(row).getByText(/Withheld — fewer than 5 people/)).toBeInTheDocument()
    // The group's existence is never hidden, only its numbers.
    expect(within(row).getByText("3")).toBeInTheDocument()
  })

  it("reports the pay gap with an explicit sign and omits suppressed cells", async () => {
    stubApi({ "/insights": insights() })

    renderPage(<InsightsPage />)

    expect(await screen.findByText("−2.5%")).toBeInTheDocument()
    expect(screen.getByText(/1 of 3 groups are withheld/)).toBeInTheDocument()
    expect(screen.queryByText("Non binary")).not.toBeInTheDocument()
  })
})
