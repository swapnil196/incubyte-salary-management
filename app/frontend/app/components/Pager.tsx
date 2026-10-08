import { Group, Pagination, Text } from "@mantine/core"

interface Props {
  page: number
  totalPages: number
  onChange: (page: number) => void
}

export function Pager({ page, totalPages, onChange }: Props) {
  return (
    <Group justify="space-between" wrap="wrap">
      <Text size="sm" c="dimmed">
        Page {page} of {totalPages.toLocaleString("en-GB")}
      </Text>
      <Pagination value={page} total={totalPages} onChange={onChange} size="sm" withEdges />
    </Group>
  )
}
