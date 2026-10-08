import {
  formatBandStatus,
  formatChangeReason,
  formatDate,
  formatMoney,
  formatMoneyCompact,
  formatPercent,
  formatRatio,
} from "./format"

describe("formatMoney", () => {
  it("renders minor units as a currency amount", () => {
    expect(formatMoney(6_600_000, "EUR")).toBe("€66,000")
  })

  it("respects the currency it is given", () => {
    // en-GB disambiguates dollars, which is what a multi-country HR team wants:
    // "US$" rather than a bare "$" that could be any of several currencies.
    expect(formatMoney(100_000, "USD")).toBe("US$1,000")
  })

  it("renders a dash for a missing amount rather than zero", () => {
    // An employee with no salary recorded is not an employee paid nothing.
    expect(formatMoney(null, "EUR")).toBe("—")
    expect(formatMoney(undefined, "EUR")).toBe("—")
  })

  it("renders an actual zero as zero", () => {
    expect(formatMoney(0, "EUR")).toBe("€0")
  })
})

describe("formatMoneyCompact", () => {
  it("shortens large totals so a dashboard tile stays readable", () => {
    expect(formatMoneyCompact(65_745_539_300, "EUR")).toBe("€657.5M")
  })
})

describe("formatPercent", () => {
  it("renders one decimal place", () => {
    expect(formatPercent(10.25)).toBe("10.3%")
  })

  it("shows an explicit sign when asked" , () => {
    expect(formatPercent(4.2, true)).toBe("+4.2%")
    expect(formatPercent(-4.2, true)).toBe("−4.2%")
  })

  it("renders a dash for a suppressed or absent figure", () => {
    expect(formatPercent(null)).toBe("—")
  })
})

describe("formatRatio", () => {
  it("renders a compa-ratio to two places", () => {
    expect(formatRatio(1.1)).toBe("1.10")
    expect(formatRatio(0.9259)).toBe("0.93")
  })

  it("renders a dash when there is no band to compare against", () => {
    expect(formatRatio(null)).toBe("—")
  })
})

describe("formatDate", () => {
  it("renders an ISO date in a readable form", () => {
    expect(formatDate("2026-01-15")).toBe("15 Jan 2026")
  })

  it("renders a dash for an open-ended period", () => {
    expect(formatDate(null)).toBe("—")
  })
})

describe("labels", () => {
  it("renders change reasons in words", () => {
    expect(formatChangeReason("market_adjustment")).toBe("Market adjustment")
  })

  it("falls back to the raw value for a reason it does not know", () => {
    expect(formatChangeReason("something_new")).toBe("something_new")
  })

  it("renders band status in words, including the absent case", () => {
    expect(formatBandStatus("below_minimum")).toBe("Below minimum")
    expect(formatBandStatus(null)).toBe("No band")
  })
})
