import { Card, Text, Title } from "@mantine/core"
import type { ReactNode } from "react"

interface Props {
  label: string
  value: string
  detail?: ReactNode
}

// A headline figure is not a chart. These are the four numbers the HR Manager
// came for, so they get size and nothing else competing with them.
export function StatTile({ label, value, detail }: Props) {
  return (
    <Card withBorder padding="md">
      <Text size="xs" c="dimmed" tt="uppercase" fw={600} lts={0.5}>
        {label}
      </Text>
      <Title order={2} ff="monospace" mt={4} style={{ fontVariantNumeric: "tabular-nums" }}>
        {value}
      </Title>
      {detail && (
        <Text size="xs" c="dimmed" mt={2}>
          {detail}
        </Text>
      )}
    </Card>
  )
}
