class AddNameSortIndexToEmployees < ActiveRecord::Migration[8.1]
  # Name is the directory's default sort, so this is the single most requested
  # ordering in the application. Without an index SQLite sorts all ~9,200 active
  # employees into a temporary B-tree on every page view.
  #
  # Measured on 10,000 employees, query cache disabled:
  #
  #   page 1    15.35 ms -> 2.50 ms
  #   page 300  48.37 ms -> 17.30 ms
  #
  # Partial, because the directory defaults to active employees and indexing
  # the leavers as well would make it larger for no benefit.
  def change
    add_index :employees, %i[last_name first_name],
              where: "terminated_on IS NULL",
              name: "idx_employees_active_by_name"
  end
end
