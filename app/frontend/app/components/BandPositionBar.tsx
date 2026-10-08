import { Box, Group, Text } from "@mantine/core"
import type { Band } from "~/app/api/types"
import { formatMoney } from "~/app/lib/format"

interface Props {
  band: Band
  amountCents: number | null
}

// Shows where a salary sits between the band minimum and maximum.
//
// The scale is widened 15% beyond each edge so someone paid outside their band
// still appears on the chart. Clamping them to the end would render an
// out-of-band salary identically to one sitting exactly on the boundary, which
// is the single most important distinction this control has to make.
const OVERHANG = 0.15

export function BandPositionBar({ band, amountCents }: Props) {
  const span = band.max_cents - band.min_cents || band.max_cents || 1
  const low = band.min_cents - span * OVERHANG
  const high = band.max_cents + span * OVERHANG
  const scale = (cents: number) => ((cents - low) / (high - low)) * 100

  const marker = amountCents === null ? null : Math.min(Math.max(scale(amountCents), 0), 100)
  const outOfBand =
    amountCents !== null && (amountCents < band.min_cents || amountCents > band.max_cents)

  return (
    <Box>
      <Box pos="relative" h={38} mt="xs">
        {/* The band itself */}
        <Box
          pos="absolute"
          top={14}
          left={`${scale(band.min_cents)}%`}
          w={`${scale(band.max_cents) - scale(band.min_cents)}%`}
          h={10}
          bg="var(--mantine-color-default-border)"
          style={{ borderRadius: 5 }}
        />
        {/* Midpoint */}
        <Box
          pos="absolute"
          top={10}
          left={`${scale(band.mid_cents)}%`}
          w={2}
          h={18}
          bg="var(--mantine-color-dimmed)"
        />
        {marker !== null && (
          <Box
            pos="absolute"
            top={8}
            left={`${marker}%`}
            w={12}
            h={22}
            bg={outOfBand ? "var(--mantine-color-orange-6)" : "var(--mantine-color-teal-6)"}
            style={{ borderRadius: 3, transform: "translateX(-50%)" }}
          />
        )}
      </Box>

      <Group justify="space-between" gap="xs">
        <Text size="xs" c="dimmed" ff="monospace">
          {formatMoney(band.min_cents, band.currency)}
        </Text>
        <Text size="xs" c="dimmed" ff="monospace">
          {formatMoney(band.mid_cents, band.currency)}
        </Text>
        <Text size="xs" c="dimmed" ff="monospace">
          {formatMoney(band.max_cents, band.currency)}
        </Text>
      </Group>
    </Box>
  )
}
