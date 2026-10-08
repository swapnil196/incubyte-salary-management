export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message)
    this.name = "ApiError"
  }
}

const BASE = "/api/v1"

function queryString(params: Record<string, unknown>): string {
  const search = new URLSearchParams()

  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null || value === "") continue
    search.set(key, String(value))
  }

  const encoded = search.toString()
  return encoded ? `?${encoded}` : ""
}

// Reads the server's error message when there is one. A 422 from this API
// always carries a human-readable reason, and discarding it in favour of
// "Request failed" would throw away the only useful part of the response.
async function errorFrom(response: Response): Promise<ApiError> {
  let message = `Request failed with status ${response.status}`

  try {
    const body = await response.json()
    if (body?.error?.message) message = body.error.message
  } catch {
    // Not JSON. Keep the status-based message.
  }

  return new ApiError(message, response.status)
}

export async function get<T>(path: string, params: Record<string, unknown> = {}): Promise<T> {
  const response = await fetch(`${BASE}${path}${queryString(params)}`, {
    headers: { Accept: "application/json" },
  })

  if (!response.ok) throw await errorFrom(response)

  return response.json() as Promise<T>
}

export async function post<T>(path: string, body: unknown): Promise<T> {
  const response = await fetch(`${BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify(body),
  })

  if (!response.ok) throw await errorFrom(response)

  return response.json() as Promise<T>
}

export function exportUrl(params: Record<string, unknown>): string {
  return `${BASE}/employees/export${queryString(params)}`
}
