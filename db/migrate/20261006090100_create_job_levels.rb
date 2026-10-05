class CreateJobLevels < ActiveRecord::Migration[8.1]
  def change
    create_table :job_levels do |t|
      t.string :name, null: false
      # Seniority order. Needed because levels sort by seniority, not
      # alphabetically: "Senior" must come after "Mid", and "L10" after "L9".
      t.integer :rank, null: false

      t.timestamps
    end

    add_index :job_levels, :name, unique: true
    add_index :job_levels, :rank, unique: true
  end
end
