import { createBrowserRouter } from "react-router-dom"
import { AppLayout } from "./components/AppLayout"
import { DirectoryPage } from "./pages/DirectoryPage"
import { EmployeePage } from "./pages/EmployeePage"
import { InsightsPage } from "./pages/InsightsPage"
import { NotFoundPage } from "./pages/NotFoundPage"

export const router = createBrowserRouter([
  {
    path: "/",
    element: <AppLayout />,
    children: [
      { index: true, element: <DirectoryPage /> },
      { path: "employees/:id", element: <EmployeePage /> },
      { path: "insights", element: <InsightsPage /> },
      { path: "*", element: <NotFoundPage /> },
    ],
  },
])
