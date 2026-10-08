import { afterEach, vi } from "vitest"
import { ApiError, exportUrl, get, post } from "./client"

const mockFetch = (response: Partial<Response>) => {
  const spy = vi.fn().mockResolvedValue(response as Response)
  vi.stubGlobal("fetch", spy)
  return spy
}

afterEach(() => vi.unstubAllGlobals())

describe("get", () => {
  it("calls the versioned API path and returns the parsed body", async () => {
    const spy = mockFetch({ ok: true, json: async () => ({ data: [1] }) })

    await expect(get("/employees")).resolves.toEqual({ data: [1] })
    expect(spy).toHaveBeenCalledWith("/api/v1/employees", expect.anything())
  })

  it("serialises parameters and omits empty ones" , async () => {
    const spy = mockFetch({ ok: true, json: async () => ({}) })

    await get("/employees", { page: 2, q: "", country_code: undefined, status: "active" })

    expect(spy).toHaveBeenCalledWith("/api/v1/employees?page=2&status=active", expect.anything())
  })

  it("surfaces the server's message on a 422 rather than a generic failure", async () => {
    // The API always explains a 422. Discarding that message would throw away
    // the only useful part of the response.
    mockFetch({
      ok: false,
      status: 422,
      json: async () => ({ error: { message: "effective date cannot be in the future" } }),
    })

    await expect(get("/employees")).rejects.toThrow("effective date cannot be in the future")
  })

  it("falls back to a status message when the body is not JSON", async () => {
    mockFetch({
      ok: false,
      status: 500,
      json: async () => {
        throw new Error("not json")
      },
    })

    await expect(get("/employees")).rejects.toThrow("status 500")
  })

  it("exposes the status code on the error" , async () => {
    mockFetch({ ok: false, status: 404, json: async () => ({}) })

    await expect(get("/employees/1")).rejects.toMatchObject({ status: 404 } as Partial<ApiError>)
  })
})

describe("post", () => {
  it("sends JSON", async () => {
    const spy = mockFetch({ ok: true, json: async () => ({ data: {} }) })

    await post("/employees/1/salary_records", { salary_record: { amount: "1" } })

    expect(spy).toHaveBeenCalledWith(
      "/api/v1/employees/1/salary_records",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({ salary_record: { amount: "1" } }),
      }),
    )
  })
})

describe("exportUrl", () => {
  it("carries the current filters, so the file matches the screen", () => {
    expect(exportUrl({ country_code: "DE", status: "active", q: "" })).toBe(
      "/api/v1/employees/export?country_code=DE&status=active",
    )
  })
})
