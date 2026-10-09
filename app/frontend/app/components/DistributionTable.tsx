import { Box, Group, Table, Text, Tooltip } from "@mantine/core"
import type { Distribution } from "~/app/api/types"
import { formatMoney } from "~/app/lib/format"

interface Props {
  rows: Distribution[]
  currency: string
  minimumGroupSize: number
  label: string
}

// A range plot, one row per group: the bar spans p25 to p75 and the notch marks
// the median. Reading across, a wide bar is a group with a lot of spread, which
// is the question "how consistently do we pay this group" rendered directly.
//
// One hue, because this is a single series of magnitudes. The median is
// direct-labelled on every row rather than relying on the axis.
export function DistributionTable({ rows, currency, minimumGroupSize, label }: Props) {
  const ceiling = Math.max(
    ...rows.map((row) => (row.suppressed ? 0 : row.p75_cents)),
    1,
  )
  const scale = (cents: number) => (cents / ceiling) * 100

  return (
    <Table.ScrollContainer minWidth={560}>
      <Table verticalSpacing="xs">
        <Table.Thead>
          <Table.Tr>
            <Table.Th>{label}</Table.Th>
            <Table.Th ta="right">People</Table.Th>
            <Table.Th ta="right">Median</Table.Th>
            <Table.Th w="45%">Range (25th–75th percentile)</Table.Th>
          </Table.Tr>
        </Table.Thead>
        <Table.Tbody>
          {rows.map((row) => (
            <Table.Tr key={row.key}>
              <Table.Td fw={500}>{row.key}</Table.Td>
              <Table.Td ta="right" ff="monospace">
                {row.headcount.toLocaleString("en-GB")}
              </Table.Td>
              <Table.Td ta="right" ff="monospace">
                {row.suppressed ? "—" : formatMoney(row.median_cents, currency)}
              </Table.Td>
              <Table.Td>
                {row.suppressed ? (
                  <Text size="xs" c="dimmed">
                    Withheld — fewer than {minimumGroupSize} people
                  </Text>
                ) : (
                  <Tooltip
                    label={`${formatMoney(row.p25_cents, currency)} – ${formatMoney(row.p75_cents, currency)}`}
                    withArrow
                  >
                    <Box pos="relative" h={18} w="100%">
                      <Box
                        pos="absolute"
                        top={6}
                        left={`${scale(row.p25_cents)}%`}
                        w={`${Math.max(scale(row.p75_cents) - scale(row.p25_cents), 0.5)}%`}
                        h={6}
                        bg="var(--mantine-color-teal-3)"
                        style={{ borderRadius: 3 }}
                      />
                      <Box
                        pos="absolute"
                        top={2}
                        left={`${scale(row.median_cents)}%`}
                        w={3}
                        h={14}
                        bg="var(--mantine-color-teal-7)"
                        style={{ borderRadius: 2, transform: "translateX(-50%)" }}
                      />
                    </Box>
                  </Tooltip>
                )}
              </Table.Td>
            </Table.Tr>
          ))}
        </Table.Tbody>
      </Table>
      <Group gap="xs" mt="xs" px="xs">
        <Box w={14} h={5} bg="var(--mantine-color-teal-3)" style={{ borderRadius: 3 }} />
        <Text size="xs" c="dimmed">
          25th–75th percentile
        </Text>
        <Box w={3} h={11} bg="var(--mantine-color-teal-7)" style={{ borderRadius: 2 }} ml="sm" />
        <Text size="xs" c="dimmed">
          Median
        </Text>
      </Group>
    </Table.ScrollContainer>
  )
}
