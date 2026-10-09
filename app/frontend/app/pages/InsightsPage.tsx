import {
  Alert,
  Box,
  Card,
  Group,
  Paper,
  SimpleGrid,
  Stack,
  Table,
  Tabs,
  Text,
  Title,
} from "@mantine/core"
import { useQuery } from "@tanstack/react-query"
import type { Insights } from "~/app/api/types"
import { fetchInsights } from "~/app/api/employees"
import { DistributionTable } from "~/app/components/DistributionTable"
import { QueryBoundary } from "~/app/components/QueryBoundary"
import { StatTile } from "~/app/components/StatTile"
import { formatMoney, formatMoneyCompact, formatPercent } from "~/app/lib/format"

// Status colours, kept separate from the single accent hue the distribution
// charts use. Each is shipped with its label, never colour alone.
const BAND_SEGMENTS = [
  { key: "below_minimum", label: "Below minimum", colour: "var(--mantine-color-orange-5)" },
  { key: "within_band", label: "In band", colour: "var(--mantine-color-gray-4)" },
  { key: "above_maximum", label: "Above maximum", colour: "var(--mantine-color-grape-5)" },
] as const

export function InsightsPage() {
  const insights = useQuery({ queryKey: ["insights"], queryFn: () => fetchInsights() })

  return (
    <QueryBoundary isPending={insights.isPending} error={insights.error}>
      {insights.data && (
        <Stack gap="md">
          <div>
            <Title order={2}>Insights</Title>
            <Text c="dimmed" size="sm">
              Active employees only, converted to {insights.data.meta.base_currency}
            </Text>
          </div>

          <SimpleGrid cols={{ base: 1, xs: 2, md: 4 }} spacing="md">
            <StatTile
              label="Annual payroll"
              value={formatMoneyCompact(
                insights.data.summary.annual_payroll_cents,
                insights.data.summary.currency,
              )}
              detail={formatMoney(
                insights.data.summary.annual_payroll_cents,
                insights.data.summary.currency,
              )}
            />
            <StatTile
              label="Headcount"
              value={insights.data.summary.headcount.toLocaleString("en-GB")}
              detail="Currently employed"
            />
            <StatTile
              label="Median salary"
              value={formatMoney(
                insights.data.summary.median_cents,
                insights.data.summary.currency,
              )}
              detail="Half the organisation earns less than this"
            />
            <StatTile
              label="Middle 50% range"
              value={`${formatMoneyCompact(insights.data.summary.p25_cents, insights.data.summary.currency)} – ${formatMoneyCompact(insights.data.summary.p75_cents, insights.data.summary.currency)}`}
              detail="25th to 75th percentile"
            />
          </SimpleGrid>

          <Card withBorder padding="md">
            <Title order={4}>Against pay bands</Title>
            <Text size="sm" c="dimmed" mb="sm">
              Who sits outside the expected range for their level and country
            </Text>

            <BandStatusBar counts={insights.data.band_status} />
          </Card>

          <Paper withBorder p="md">
            <Title order={4} mb="sm">
              How pay is distributed
            </Title>
            <Tabs defaultValue="level">
              <Tabs.List mb="sm">
                <Tabs.Tab value="level">By level</Tabs.Tab>
                <Tabs.Tab value="country">By country</Tabs.Tab>
                <Tabs.Tab value="department">By department</Tabs.Tab>
              </Tabs.List>

              <Tabs.Panel value="level">
                <DistributionTable
                  rows={insights.data.by_level}
                  currency={insights.data.meta.base_currency}
                  minimumGroupSize={insights.data.meta.minimum_group_size}
                  label="Level"
                />
              </Tabs.Panel>
              <Tabs.Panel value="country">
                <DistributionTable
                  rows={insights.data.by_country}
                  currency={insights.data.meta.base_currency}
                  minimumGroupSize={insights.data.meta.minimum_group_size}
                  label="Country"
                />
              </Tabs.Panel>
              <Tabs.Panel value="department">
                <DistributionTable
                  rows={insights.data.by_department}
                  currency={insights.data.meta.base_currency}
                  minimumGroupSize={insights.data.meta.minimum_group_size}
                  label="Department"
                />
              </Tabs.Panel>
            </Tabs>
          </Paper>

          <PayEquity data={insights.data} />
        </Stack>
      )}
    </QueryBoundary>
  )
}

function BandStatusBar({ counts }: { counts: Record<string, number> }) {
  const total = BAND_SEGMENTS.reduce((sum, segment) => sum + (counts[segment.key] ?? 0), 0) || 1

  return (
    <>
      <Group gap={2} wrap="nowrap" mb="xs">
        {BAND_SEGMENTS.map((segment) => {
          const count = counts[segment.key] ?? 0
          if (count === 0) return null

          return (
            <Box
              key={segment.key}
              h={16}
              bg={segment.colour}
              w={`${(count / total) * 100}%`}
              style={{ borderRadius: 3 }}
            />
          )
        })}
      </Group>
      <Group gap="lg" wrap="wrap">
        {BAND_SEGMENTS.map((segment) => (
          <Group key={segment.key} gap={6} wrap="nowrap">
            <Box w={10} h={10} bg={segment.colour} style={{ borderRadius: 2 }} />
            <Text size="sm">
              <Text span fw={600} ff="monospace">
                {(counts[segment.key] ?? 0).toLocaleString("en-GB")}
              </Text>{" "}
              <Text span c="dimmed">
                {segment.label}
              </Text>
            </Text>
          </Group>
        ))}
      </Group>
    </>
  )
}

function PayEquity({ data }: { data: Insights }) {
  const reported = data.pay_equity.filter((cell) => !cell.suppressed)
  const suppressed = data.pay_equity.length - reported.length

  return (
    <Paper withBorder p="md">
      <Title order={4}>Pay equity</Title>
      <Text size="sm" c="dimmed" mb="sm">
        Median pay by gender, compared within the same level and country. Comparing across the
        whole organisation would mostly measure who holds the senior roles.
      </Text>

      {suppressed > 0 && (
        <Alert variant="light" color="gray" mb="sm">
          {suppressed} of {data.pay_equity.length} groups are withheld because they contain fewer
          than {data.meta.minimum_group_size} people, which would identify individual salaries.
        </Alert>
      )}

      <Table.ScrollContainer minWidth={640}>
        <Table verticalSpacing="xs" highlightOnHover>
          <Table.Thead>
            <Table.Tr>
              <Table.Th>Level</Table.Th>
              <Table.Th>Country</Table.Th>
              <Table.Th>Gender</Table.Th>
              <Table.Th ta="right">People</Table.Th>
              <Table.Th ta="right">Median</Table.Th>
              <Table.Th ta="right">vs largest group</Table.Th>
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {reported.map((cell) => (
              <Table.Tr key={`${cell.job_level}-${cell.country_code}-${cell.gender}`}>
                <Table.Td>{cell.job_level}</Table.Td>
                <Table.Td>{cell.country_code}</Table.Td>
                <Table.Td tt="capitalize">{(cell.gender ?? "unknown").replace("_", " ")}</Table.Td>
                <Table.Td ta="right" ff="monospace">
                  {cell.headcount}
                </Table.Td>
                <Table.Td ta="right" ff="monospace">
                  {formatMoney(cell.median_cents, data.meta.base_currency)}
                </Table.Td>
                <Table.Td ta="right" ff="monospace">
                  <Text
                    span
                    size="sm"
                    c={
                      cell.difference_from_reference_pct === null ||
                      Math.abs(cell.difference_from_reference_pct) < 0.05
                        ? "dimmed"
                        : cell.difference_from_reference_pct < 0
                          ? "orange.7"
                          : "teal.7"
                    }
                  >
                    {formatPercent(cell.difference_from_reference_pct, true)}
                  </Text>
                </Table.Td>
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
      </Table.ScrollContainer>
    </Paper>
  )
}
