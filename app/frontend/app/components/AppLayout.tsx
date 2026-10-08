import { Anchor, AppShell, Badge, Group, Text, Title } from "@mantine/core"
import { Link, Outlet, useLocation } from "react-router-dom"

const NAV = [
  { to: "/", label: "Directory" },
  { to: "/insights", label: "Insights" },
]

export function AppLayout() {
  const { pathname } = useLocation()

  return (
    <AppShell header={{ height: 60 }} padding="md">
      <AppShell.Header>
        <Group h="100%" px="md" justify="space-between" wrap="nowrap">
          <Group gap="xl" wrap="nowrap">
            <Title order={4} style={{ whiteSpace: "nowrap" }}>
              Salary Management
            </Title>
            <Group gap="md">
              {NAV.map((item) => {
                const active = item.to === "/" ? pathname === "/" : pathname.startsWith(item.to)

                return (
                  <Anchor
                    key={item.to}
                    component={Link}
                    to={item.to}
                    c={active ? undefined : "dimmed"}
                    fw={active ? 600 : 400}
                    underline="never"
                  >
                    {item.label}
                  </Anchor>
                )
              })}
            </Group>
          </Group>
          <Group gap="xs" visibleFrom="sm">
            <Badge variant="light" color="gray">
              ACME
            </Badge>
            <Text size="sm" c="dimmed">
              HR Manager
            </Text>
          </Group>
        </Group>
      </AppShell.Header>

      <AppShell.Main>
        <Outlet />
      </AppShell.Main>
    </AppShell>
  )
}
