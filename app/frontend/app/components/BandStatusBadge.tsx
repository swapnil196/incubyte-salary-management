import { Badge } from "@mantine/core"
import type { BandStatus } from "~/app/api/types"
import { formatBandStatus } from "~/app/lib/format"

// Colour carries the same information as the text, so the row can be scanned
// without reading it. Semantic colours, kept separate from the brand accent.
const COLOURS: Record<BandStatus, string> = {
  below_minimum: "orange",
  within_band: "gray",
  above_maximum: "grape",
}

export function BandStatusBadge({ status }: { status: BandStatus | null }) {
  if (!status) {
    return (
      <Badge variant="outline" color="gray" size="sm">
        No band
      </Badge>
    )
  }

  return (
    <Badge variant="light" color={COLOURS[status]} size="sm">
      {formatBandStatus(status)}
    </Badge>
  )
}
