// Mirrors the JSON the Rails API returns. Kept hand-written rather than
// generated: the API is small, and a type that drifts loudly in review is
// better than a generator nobody runs.

export type BandStatus = "below_minimum" | "within_band" | "above_maximum"
export type EmployeeStatus = "active" | "terminated"

export interface Salary {
  amount_cents: number
  currency: string
  base_amount_cents: number
  base_currency: string
  effective_from: string
}

export interface Band {
  min_cents: number
  mid_cents: number
  max_cents: number
  currency: string
  compa_ratio: number | null
  status: BandStatus | null
}

export interface EmployeeListItem {
  id: number
  employee_number: string
  full_name: string
  email: string
  country_code: string
  department: string
  job_level: string
  status: EmployeeStatus
  hired_on: string
  terminated_on: string | null
  salary: Salary | null
  band: Band | null
}

export interface SalaryHistoryEntry extends Salary {
  id: number
  effective_to: string | null
  change_reason: string
  current: boolean
  change_from_previous: number | null
  fx_rate: string
  fx_rate_date: string
}

export interface EmployeeDetail {
  id: number
  employee_number: string
  first_name: string
  last_name: string
  full_name: string
  email: string
  country_code: string
  gender: string | null
  department: { id: number; name: string }
  job_level: { id: number; name: string; rank: number }
  status: EmployeeStatus
  hired_on: string
  terminated_on: string | null
  current_salary: SalaryHistoryEntry | null
  band: Band | null
  salary_history: SalaryHistoryEntry[]
}

export interface PageMeta {
  page: number
  per_page: number
  total_count: number
  total_pages: number
  sort: string
  direction: "asc" | "desc"
  status: string
}

export interface EmployeesResponse {
  data: EmployeeListItem[]
  meta: PageMeta
}

// A breakdown row is either suppressed, carrying only a headcount, or complete.
// Modelled as a union so the UI cannot read a median that is not there.
export type Distribution =
  | { key: string; headcount: number; suppressed: true }
  | {
      key: string
      headcount: number
      suppressed: false
      median_cents: number
      p25_cents: number
      p75_cents: number
    }

export type EquityCell = {
  job_level: string
  country_code: string
  gender: string | null
  headcount: number
  difference_from_reference_pct: number | null
} & ({ suppressed: true } | { suppressed: false; median_cents: number; p25_cents: number; p75_cents: number })

export interface Insights {
  summary: {
    headcount: number
    annual_payroll_cents: number
    currency: string
    median_cents: number | null
    p25_cents: number | null
    p75_cents: number | null
  }
  by_country: Distribution[]
  by_department: Distribution[]
  by_level: Distribution[]
  band_status: { below_minimum: number; within_band: number; above_maximum: number }
  pay_equity: EquityCell[]
  meta: { base_currency: string; minimum_group_size: number }
}
