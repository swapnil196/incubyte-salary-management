import { get, post } from "./client"
import type { EmployeeDetail, EmployeesResponse, Insights } from "./types"

export interface DirectoryFilters {
  page?: number
  per_page?: number
  q?: string
  sort?: string
  direction?: "asc" | "desc"
  status?: string
  country_code?: string
  department_id?: string
  job_level_id?: string
}

export const fetchEmployees = (filters: DirectoryFilters) =>
  get<EmployeesResponse>("/employees", filters as Record<string, unknown>)

export const fetchEmployee = (id: number | string) =>
  get<{ data: EmployeeDetail }>(`/employees/${id}`).then((r) => r.data)

export const fetchInsights = (filters: Record<string, unknown> = {}) =>
  get<{ data: Insights }>("/insights", filters).then((r) => r.data)

export interface SalaryChangeInput {
  amount: string
  currency: string
  effective_from: string
  change_reason: string
}

export const recordSalaryChange = (employeeId: number, input: SalaryChangeInput) =>
  post<{ data: unknown }>(`/employees/${employeeId}/salary_records`, { salary_record: input })
