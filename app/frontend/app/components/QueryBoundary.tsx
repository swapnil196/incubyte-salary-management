import { Alert, Center, Loader } from "@mantine/core"
import type { ReactNode } from "react"

interface Props {
  isPending: boolean
  error: Error | null
  children: ReactNode
}

// One place that decides what loading and failure look like, so every page
// behaves the same way and no page quietly renders an empty table when the
// request actually failed.
export function QueryBoundary({ isPending, error, children }: Props) {
  if (isPending) {
    return (
      <Center mih={240}>
        <Loader />
      </Center>
    )
  }

  if (error) {
    return (
      <Alert color="red" title="Could not load this data" variant="light">
        {error.message}
      </Alert>
    )
  }

  return <>{children}</>
}
