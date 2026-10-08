import { MantineProvider } from "@mantine/core"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { RouterProvider } from "react-router-dom"
import "@mantine/core/styles.css"
import { router } from "./router"
import { theme } from "./theme"

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Salary data changes rarely, and only from this one user, so refetching
      // on every window focus is noise rather than freshness.
      refetchOnWindowFocus: false,
      staleTime: 30_000,
      retry: 1,
    },
  },
})

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <MantineProvider theme={theme} defaultColorScheme="auto">
        <RouterProvider router={router} />
      </MantineProvider>
    </QueryClientProvider>
  )
}
