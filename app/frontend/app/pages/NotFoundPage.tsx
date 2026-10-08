import { Anchor, Stack, Text, Title } from "@mantine/core"
import { Link } from "react-router-dom"

export function NotFoundPage() {
  return (
    <Stack gap="xs" mt="xl" align="center">
      <Title order={2}>Page not found</Title>
      <Text c="dimmed">That address does not match anything in this application.</Text>
      <Anchor component={Link} to="/">
        Back to the directory
      </Anchor>
    </Stack>
  )
}
