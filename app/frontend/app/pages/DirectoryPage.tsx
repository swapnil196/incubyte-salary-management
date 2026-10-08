import {
  Anchor,
  Badge,
  Button,
  Group,
  Paper,
  Select,
  Stack,
  Table,
  Text,
  TextInput,
  Title,
  UnstyledButton,
} from "@mantine/core"
import { useDebouncedValue } from "@mantine/hooks"
import { keepPreviousData, useQuery } from "@tanstack/react-query"
import { useEffect, useState } from "react"
import { Link, useSearchParams } from "react-router-dom"
import { exportUrl } from "~/app/api/client"
import { fetchEmployees, fetchReference } from "~/app/api/employees"
import { BandStatusBadge } from "~/app/components/BandStatusBadge"
import { Pager } from "~/app/components/Pager"
import { QueryBoundary } from "~/app/components/QueryBoundary"
import { formatMoney, formatRatio } from "~/app/lib/format"

type SortKey = "name" | "department" | "level" | "country" | "hired_on" | "salary" | "compa_ratio"

const COLUMNS: { key: SortKey; label: string; numeric?: boolean }[] = [
  { key: "name", label: "Name" },
  { key: "department", label: "Department" },
  { key: "level", label: "Level" },
  { key: "country", label: "Country" },
  { key: "salary", label: "Salary", numeric: true },
  { key: "compa_ratio", label: "Compa-ratio", numeric: true },
]

const STATUS_OPTIONS = [
  { value: "active", label: "Active" },
  { value: "terminated", label: "Left" },
  { value: "all", label: "Everyone" },
]

export function DirectoryPage() {
  const [params, setParams] = useSearchParams()
  const [search, setSearch] = useState(params.get("q") ?? "")
  const [debouncedSearch] = useDebouncedValue(search, 300)

  // Filters live in the URL rather than in component state, so a filtered view
  // can be bookmarked, shared with a colleague, and survives a reload.
  const filters = {
    q: params.get("q") ?? undefined,
    page: Number(params.get("page") ?? 1),
    status: params.get("status") ?? "active",
    country_code: params.get("country_code") ?? undefined,
    department_id: params.get("department_id") ?? undefined,
    job_level_id: params.get("job_level_id") ?? undefined,
    sort: params.get("sort") ?? "name",
    direction: (params.get("direction") ?? "asc") as "asc" | "desc",
  }

  const update = (changes: Record<string, string | undefined>, resetPage = true) => {
    const next = new URLSearchParams(params)

    for (const [key, value] of Object.entries(changes)) {
      if (value === undefined || value === "") next.delete(key)
      else next.set(key, value)
    }
    if (resetPage) next.delete("page")

    setParams(next, { replace: true })
  }

  // Typing updates the URL only after the debounce, so the history is not
  // filled with one entry per keystroke and the API is not called per letter.
  useEffect(() => {
    if (debouncedSearch !== (params.get("q") ?? "")) update({ q: debouncedSearch || undefined })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [debouncedSearch])

  const reference = useQuery({ queryKey: ["reference"], queryFn: fetchReference })

  const employees = useQuery({
    queryKey: ["employees", filters],
    queryFn: () => fetchEmployees(filters),
    // Keeps the previous page visible while the next one loads, so the table
    // does not collapse to a spinner on every sort or page change.
    placeholderData: keepPreviousData,
  })

  const toggleSort = (key: SortKey) => {
    const sameColumn = filters.sort === key
    update(
      { sort: key, direction: sameColumn && filters.direction === "asc" ? "desc" : "asc" },
      false,
    )
  }

  const meta = employees.data?.meta

  return (
    <Stack gap="md">
      <Group justify="space-between" align="flex-end" wrap="wrap">
        <div>
          <Title order={2}>Directory</Title>
          <Text c="dimmed" size="sm">
            {meta ? `${meta.total_count.toLocaleString("en-GB")} employees` : " "}
          </Text>
        </div>
        <Button
          component="a"
          href={exportUrl(filters)}
          variant="default"
          disabled={!meta?.total_count}
        >
          Export CSV
        </Button>
      </Group>

      <Paper withBorder p="sm">
        <Group gap="sm" align="flex-end" wrap="wrap">
          <TextInput
            label="Search"
            placeholder="Name, email or employee number"
            value={search}
            onChange={(event) => setSearch(event.currentTarget.value)}
            w={{ base: "100%", sm: 260 }}
          />
          <Select
            label="Country"
            placeholder="All"
            clearable
            data={reference.data?.countries ?? []}
            value={filters.country_code ?? null}
            onChange={(value) => update({ country_code: value ?? undefined })}
            w={{ base: "100%", sm: 130 }}
          />
          <Select
            label="Department"
            placeholder="All"
            clearable
            data={(reference.data?.departments ?? []).map((d) => ({
              value: String(d.id),
              label: d.name,
            }))}
            value={filters.department_id ?? null}
            onChange={(value) => update({ department_id: value ?? undefined })}
            w={{ base: "100%", sm: 180 }}
          />
          <Select
            label="Level"
            placeholder="All"
            clearable
            data={(reference.data?.job_levels ?? []).map((l) => ({
              value: String(l.id),
              label: l.name,
            }))}
            value={filters.job_level_id ?? null}
            onChange={(value) => update({ job_level_id: value ?? undefined })}
            w={{ base: "100%", sm: 150 }}
          />
          <Select
            label="Status"
            data={STATUS_OPTIONS}
            value={filters.status}
            onChange={(value) => update({ status: value ?? "active" })}
            w={{ base: "100%", sm: 130 }}
            allowDeselect={false}
          />
        </Group>
      </Paper>

      <QueryBoundary isPending={employees.isPending} error={employees.error}>
        <Paper withBorder>
          <Table.ScrollContainer minWidth={820}>
            <Table highlightOnHover verticalSpacing="sm">
              <Table.Thead>
                <Table.Tr>
                  {COLUMNS.map((column) => (
                    <Table.Th
                      key={column.key}
                      style={{ textAlign: column.numeric ? "right" : "left" }}
                    >
                      <UnstyledButton onClick={() => toggleSort(column.key)} fz="sm" fw={600}>
                        {column.label}
                        {filters.sort === column.key ? (filters.direction === "asc" ? " ↑" : " ↓") : ""}
                      </UnstyledButton>
                    </Table.Th>
                  ))}
                  <Table.Th>Band</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>
                {employees.data?.data.map((employee) => (
                  <Table.Tr key={employee.id}>
                    <Table.Td>
                      <Anchor component={Link} to={`/employees/${employee.id}`} fw={500}>
                        {employee.full_name}
                      </Anchor>
                      <Text size="xs" c="dimmed">
                        {employee.employee_number}
                        {employee.status === "terminated" ? " · left" : ""}
                      </Text>
                    </Table.Td>
                    <Table.Td>{employee.department}</Table.Td>
                    <Table.Td>{employee.job_level}</Table.Td>
                    <Table.Td>
                      <Badge variant="default" size="sm">
                        {employee.country_code}
                      </Badge>
                    </Table.Td>
                    <Table.Td ta="right" ff="monospace">
                      {employee.salary
                        ? formatMoney(employee.salary.amount_cents, employee.salary.currency)
                        : "—"}
                      {employee.salary && employee.salary.currency !== employee.salary.base_currency && (
                        <Text size="xs" c="dimmed" ff="monospace">
                          {formatMoney(
                            employee.salary.base_amount_cents,
                            employee.salary.base_currency,
                          )}
                        </Text>
                      )}
                    </Table.Td>
                    <Table.Td ta="right" ff="monospace">
                      {formatRatio(employee.band?.compa_ratio)}
                    </Table.Td>
                    <Table.Td>
                      <BandStatusBadge status={employee.band?.status ?? null} />
                    </Table.Td>
                  </Table.Tr>
                ))}
              </Table.Tbody>
            </Table>
          </Table.ScrollContainer>

          {employees.data?.data.length === 0 && (
            <Text c="dimmed" ta="center" py="xl">
              No employees match these filters.
            </Text>
          )}
        </Paper>

        {meta && meta.total_pages > 1 && (
          <Pager
            page={meta.page}
            totalPages={meta.total_pages}
            onChange={(page) => update({ page: String(page) }, false)}
          />
        )}
      </QueryBoundary>
    </Stack>
  )
}
