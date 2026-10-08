import {
  Anchor,
  Badge,
  Button,
  Card,
  Group,
  Paper,
  SimpleGrid,
  Stack,
  Text,
  Timeline,
  Title,
} from "@mantine/core"
import { useDisclosure } from "@mantine/hooks"
import { useQuery } from "@tanstack/react-query"
import { Link, useParams } from "react-router-dom"
import { fetchEmployee, fetchReference } from "~/app/api/employees"
import { BandPositionBar } from "~/app/components/BandPositionBar"
import { BandStatusBadge } from "~/app/components/BandStatusBadge"
import { QueryBoundary } from "~/app/components/QueryBoundary"
import { SalaryChangeForm } from "~/app/components/SalaryChangeForm"
import {
  formatChangeReason,
  formatDate,
  formatMoney,
  formatPercent,
  formatRatio,
} from "~/app/lib/format"

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <Text size="xs" c="dimmed" tt="uppercase" fw={600} lts={0.5}>
        {label}
      </Text>
      <Text size="sm">{children}</Text>
    </div>
  )
}

export function EmployeePage() {
  const { id } = useParams<{ id: string }>()
  const [formOpen, form] = useDisclosure(false)

  const employeeId = Number(id)
  const employee = useQuery({
    queryKey: ["employee", employeeId],
    queryFn: () => fetchEmployee(employeeId),
  })
  const reference = useQuery({ queryKey: ["reference"], queryFn: fetchReference })

  return (
    <QueryBoundary isPending={employee.isPending} error={employee.error}>
      {employee.data && (
        <Stack gap="md">
          <Anchor component={Link} to="/" size="sm">
            ← Directory
          </Anchor>

          <Group justify="space-between" align="flex-start" wrap="wrap">
            <div>
              <Group gap="sm">
                <Title order={2}>{employee.data.full_name}</Title>
                {employee.data.status === "terminated" && (
                  <Badge color="gray" variant="light">
                    Left {formatDate(employee.data.terminated_on)}
                  </Badge>
                )}
              </Group>
              <Text c="dimmed" size="sm">
                {employee.data.employee_number} · {employee.data.email}
              </Text>
            </div>
            <Button onClick={form.open} disabled={employee.data.status === "terminated"}>
              Record pay change
            </Button>
          </Group>

          <Paper withBorder p="md">
            <SimpleGrid cols={{ base: 2, sm: 3, md: 5 }} spacing="md">
              <Field label="Department">{employee.data.department.name}</Field>
              <Field label="Level">{employee.data.job_level.name}</Field>
              <Field label="Country">{employee.data.country_code}</Field>
              <Field label="Hired">{formatDate(employee.data.hired_on)}</Field>
              <Field label="Gender">{employee.data.gender ?? "—"}</Field>
            </SimpleGrid>
          </Paper>

          <SimpleGrid cols={{ base: 1, md: 2 }} spacing="md">
            <Card withBorder padding="md">
              <Text size="xs" c="dimmed" tt="uppercase" fw={600} lts={0.5}>
                Current salary
              </Text>
              {employee.data.current_salary ? (
                <>
                  <Title order={3} mt={4} ff="monospace">
                    {formatMoney(
                      employee.data.current_salary.amount_cents,
                      employee.data.current_salary.currency,
                    )}
                  </Title>
                  {employee.data.current_salary.currency !==
                    employee.data.current_salary.base_currency && (
                    <Text size="sm" c="dimmed" ff="monospace">
                      {formatMoney(
                        employee.data.current_salary.base_amount_cents,
                        employee.data.current_salary.base_currency,
                      )}{" "}
                      at {employee.data.current_salary.fx_rate} on{" "}
                      {formatDate(employee.data.current_salary.fx_rate_date)}
                    </Text>
                  )}
                  <Text size="sm" c="dimmed" mt={4}>
                    Effective {formatDate(employee.data.current_salary.effective_from)}
                  </Text>
                </>
              ) : (
                <Text c="dimmed" mt="xs">
                  No salary recorded.
                </Text>
              )}
            </Card>

            <Card withBorder padding="md">
              <Group justify="space-between">
                <Text size="xs" c="dimmed" tt="uppercase" fw={600} lts={0.5}>
                  Pay band · {employee.data.job_level.name}, {employee.data.country_code}
                </Text>
                <BandStatusBadge status={employee.data.band?.status ?? null} />
              </Group>

              {employee.data.band ? (
                <>
                  <Group gap="xs" mt={4} align="baseline">
                    <Title order={3} ff="monospace">
                      {formatRatio(employee.data.band.compa_ratio)}
                    </Title>
                    <Text size="sm" c="dimmed">
                      compa-ratio
                    </Text>
                  </Group>
                  <BandPositionBar
                    band={employee.data.band}
                    amountCents={employee.data.current_salary?.base_amount_cents ?? null}
                  />
                </>
              ) : (
                <Text c="dimmed" mt="xs">
                  No band defined for this level and country.
                </Text>
              )}
            </Card>
          </SimpleGrid>

          <Paper withBorder p="md">
            <Title order={4} mb="md">
              Salary history
            </Title>

            {employee.data.salary_history.length === 0 ? (
              <Text c="dimmed">Nothing recorded yet.</Text>
            ) : (
              <Timeline active={0} bulletSize={14} lineWidth={2}>
                {employee.data.salary_history.map((entry) => (
                  <Timeline.Item
                    key={entry.id}
                    title={
                      <Group gap="xs" align="baseline">
                        <Text fw={600} ff="monospace">
                          {formatMoney(entry.amount_cents, entry.currency)}
                        </Text>
                        {entry.change_from_previous !== null && (
                          <Badge
                            size="sm"
                            variant="light"
                            color={entry.change_from_previous >= 0 ? "teal" : "orange"}
                          >
                            {formatPercent(entry.change_from_previous, true)}
                          </Badge>
                        )}
                        {entry.current && (
                          <Badge size="sm" variant="dot">
                            Current
                          </Badge>
                        )}
                      </Group>
                    }
                  >
                    <Text size="sm" c="dimmed">
                      {formatChangeReason(entry.change_reason)} · {formatDate(entry.effective_from)}
                      {entry.effective_to ? ` to ${formatDate(entry.effective_to)}` : " to present"}
                    </Text>
                  </Timeline.Item>
                ))}
              </Timeline>
            )}
          </Paper>

          <SalaryChangeForm
            employeeId={employeeId}
            opened={formOpen}
            onClose={form.close}
            reference={reference.data}
            defaultCurrency={employee.data.current_salary?.currency ?? "EUR"}
          />
        </Stack>
      )}
    </QueryBoundary>
  )
}
