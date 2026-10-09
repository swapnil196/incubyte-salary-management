# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_08_120000) do
  create_table "departments", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_departments_on_name", unique: true
  end

  create_table "employees", force: :cascade do |t|
    t.string "employee_number", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "country_code", limit: 2, null: false
    t.integer "department_id", null: false
    t.integer "job_level_id", null: false
    t.string "gender"
    t.date "hired_on", null: false
    t.date "terminated_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_code", "department_id", "job_level_id"], name: "idx_employees_directory_filters"
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["email"], name: "index_employees_on_email", unique: true
    t.index ["employee_number"], name: "index_employees_on_employee_number", unique: true
    t.index ["id"], name: "idx_employees_active", where: "terminated_on IS NULL"
    t.index ["job_level_id"], name: "index_employees_on_job_level_id"
    t.index ["last_name", "first_name"], name: "idx_employees_active_by_name", where: "terminated_on IS NULL"
    t.check_constraint "terminated_on IS NULL OR terminated_on >= hired_on", name: "chk_employees_termination_after_hire"
  end

  create_table "fx_rates", force: :cascade do |t|
    t.string "currency", limit: 3, null: false
    t.string "base_currency", limit: 3, null: false
    t.decimal "rate", precision: 18, scale: 8, null: false
    t.date "rate_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency", "base_currency", "rate_date"], name: "idx_fx_rates_lookup", unique: true
  end

  create_table "job_levels", force: :cascade do |t|
    t.string "name", null: false
    t.integer "rank", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_job_levels_on_name", unique: true
    t.index ["rank"], name: "index_job_levels_on_rank", unique: true
  end

  create_table "pay_bands", force: :cascade do |t|
    t.integer "job_level_id", null: false
    t.string "country_code", limit: 2, null: false
    t.bigint "min_cents", null: false
    t.bigint "mid_cents", null: false
    t.bigint "max_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_level_id", "country_code"], name: "idx_pay_bands_level_country", unique: true
    t.index ["job_level_id"], name: "index_pay_bands_on_job_level_id"
    t.check_constraint "min_cents > 0 AND min_cents <= mid_cents AND mid_cents <= max_cents", name: "chk_pay_bands_ordered"
  end

  create_table "salary_records", force: :cascade do |t|
    t.integer "employee_id", null: false
    t.bigint "amount_cents", null: false
    t.string "currency", limit: 3, null: false
    t.bigint "base_amount_cents", null: false
    t.decimal "fx_rate", precision: 18, scale: 8, null: false
    t.date "fx_rate_date", null: false
    t.date "effective_from", null: false
    t.date "effective_to"
    t.string "change_reason", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_from"], name: "idx_salary_records_history"
    t.index ["employee_id"], name: "idx_salary_records_current", unique: true, where: "effective_to IS NULL"
    t.index ["employee_id"], name: "index_salary_records_on_employee_id"
    t.check_constraint "amount_cents > 0", name: "chk_salary_records_amount_positive"
    t.check_constraint "base_amount_cents > 0", name: "chk_salary_records_base_amount_positive"
    t.check_constraint "effective_to IS NULL OR effective_to >= effective_from", name: "chk_salary_records_period_order"
  end

  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "job_levels"
  add_foreign_key "pay_bands", "job_levels"
  add_foreign_key "salary_records", "employees"
end
