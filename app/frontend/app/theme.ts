import { createTheme } from "@mantine/core"

export const theme = createTheme({
  primaryColor: "teal",
  fontFamily:
    "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif",
  // Figures line up in columns throughout the directory and the dashboard.
  fontFamilyMonospace: "ui-monospace, SFMono-Regular, Menlo, monospace",
  defaultRadius: "sm",
  headings: { fontWeight: "600" },
})
