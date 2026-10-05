import { MantineProvider, Container, Title, Text, Stack } from "@mantine/core"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import "@mantine/core/styles.css"
import { theme } from "./theme"

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Salary data changes rarely and only from this one user, so refetching
      // on every window focus is pure noise.
      refetchOnWindowFocus: false,
      staleTime: 30_000,
    },
  },
})

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <MantineProvider theme={theme} defaultColorScheme="auto">
        <Container size="lg" py="xl">
          <Stack gap="xs">
            <Title order={1}>Salary Management</Title>
            <Text c="dimmed">Application shell. Features land in later commits.</Text>
          </Stack>
        </Container>
      </MantineProvider>
    </QueryClientProvider>
  )
}
