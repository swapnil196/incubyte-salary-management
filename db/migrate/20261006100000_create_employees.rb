class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.string :employee_number, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :country_code, null: false, limit: 2
      t.references :department, null: false, foreign_key: true
      t.references :job_level, null: false, foreign_key: true
      # Nullable and self-reported. Only ever read in aggregate for the pay
      # equity view, which suppresses groups under five people.
      t.string :gender
      t.date :hired_on, null: false
      # NULL means currently employed.
      t.date :terminated_on

      t.timestamps
    end

    add_index :employees, :employee_number, unique: true
    add_index :employees, :email, unique: true

    # The directory filters on these, usually in combination. Country leads
    # because it is the most selective of the three in a multi-country org.
    add_index :employees, %i[country_code department_id job_level_id],
              name: "idx_employees_directory_filters"

    # Serves the default "active employees only" filter. Partial, so it indexes
    # only the rows that satisfy it rather than the whole table.
    add_index :employees, :id, where: "terminated_on IS NULL",
              name: "idx_employees_active"

    # A termination cannot precede the hire it ends.
    add_check_constraint :employees,
                         "terminated_on IS NULL OR terminated_on >= hired_on",
                         name: "chk_employees_termination_after_hire"
  end
end
