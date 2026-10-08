// Money arrives from the API as integer minor units plus a currency, the same
// representation the backend stores. Formatting happens here and nowhere else,
// so a change of convention is a one-file change.

export function formatMoney(cents: number | null | undefined, currency: string): string {
  if (cents === null || cents === undefined) return "—"

  return new Intl.NumberFormat("en-GB", {
    style: "currency",
    currency,
    maximumFractionDigits: 0,
  }).format(cents / 100)
}

// Totals in the tens of millions are unreadable in full on a dashboard tile.
export function formatMoneyCompact(cents: number | null | undefined, currency: string): string {
  if (cents === null || cents === undefined) return "—"

  return new Intl.NumberFormat("en-GB", {
    style: "currency",
    currency,
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(cents / 100)
}

export function formatDate(iso: string | null | undefined): string {
  if (!iso) return "—"

  return new Intl.DateTimeFormat("en-GB", { dateStyle: "medium" }).format(new Date(iso))
}

export function formatPercent(value: number | null | undefined, signed = false): string {
  if (value === null || value === undefined) return "—"

  const formatted = `${Math.abs(value).toFixed(1)}%`
  if (!signed) return formatted

  return value >= 0 ? `+${formatted}` : `−${formatted}`
}

export function formatRatio(value: number | null | undefined): string {
  if (value === null || value === undefined) return "—"

  return value.toFixed(2)
}

const REASON_LABELS: Record<string, string> = {
  hire: "Hire",
  merit: "Merit increase",
  promotion: "Promotion",
  market_adjustment: "Market adjustment",
  demotion: "Demotion",
  correction: "Correction",
}

export const formatChangeReason = (reason: string) => REASON_LABELS[reason] ?? reason

const BAND_LABELS: Record<string, string> = {
  below_minimum: "Below minimum",
  within_band: "In band",
  above_maximum: "Above maximum",
}

export const formatBandStatus = (status: string | null) =>
  status ? (BAND_LABELS[status] ?? status) : "No band"
