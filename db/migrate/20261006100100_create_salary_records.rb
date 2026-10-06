class CreateSalaryRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :salary_records do |t|
      t.references :employee, null: false, foreign_key: true

      # What the employee is actually paid, in their own currency.
      t.bigint :amount_cents, null: false
      t.string :currency, null: false, limit: 3

      # The same amount in BASE_CURRENCY, converted once at write time using the
      # rate below. Aggregates sum this column, so a report re-run next quarter
      # returns the number it returned today (ADR 003).
      t.bigint :base_amount_cents, null: false
      t.decimal :fx_rate, precision: 18, scale: 8, null: false
      t.date :fx_rate_date, null: false

      t.date :effective_from, null: false
      # NULL means this is the salary currently in force. Exclusive end date.
      t.date :effective_to

      t.string :change_reason, null: false

      t.timestamps
    end

    # THE invariant: an employee has at most one open salary record.
    #
    # Enforced here rather than in the service layer, so a concurrent double
    # submit raises a constraint violation instead of leaving the employee with
    # two live salaries. It also makes "current pay for everyone" an index-only
    # scan, which is the hottest query in the application.
    add_index :salary_records, :employee_id, unique: true,
              where: "effective_to IS NULL",
              name: "idx_salary_records_current"

    # Serves the salary history timeline on the employee profile.
    add_index :salary_records, %i[employee_id effective_from],
              name: "idx_salary_records_history"

    # A period cannot end before it starts. Equal dates are allowed and mean the
    # record was superseded the same day it took effect, so it never applied.
    add_check_constraint :salary_records,
                         "effective_to IS NULL OR effective_to >= effective_from",
                         name: "chk_salary_records_period_order"

    # A salary of zero or less is not a correction, it is a bug.
    add_check_constraint :salary_records, "amount_cents > 0",
                         name: "chk_salary_records_amount_positive"
    add_check_constraint :salary_records, "base_amount_cents > 0",
                         name: "chk_salary_records_base_amount_positive"
  end
end
