class CreateDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :departments do |t|
      t.string :name, null: false

      t.timestamps
    end

    # Department names are the user-facing identity of a department and are used
    # as a filter value, so duplicates would silently split a department's
    # headcount across two rows.
    add_index :departments, :name, unique: true
  end
end
