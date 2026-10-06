class CreatePayBands < ActiveRecord::Migration[8.1]
  def change
    create_table :pay_bands do |t|
      t.references :job_level, null: false, foreign_key: true
      t.string :country_code, null: false, limit: 2

      # Held in BASE_CURRENCY, not in local currency.
      #
      # A band exists to answer "is this person paid correctly for their level
      # here", and the comparison is against base_amount_cents on the salary
      # record, which is already in the base currency. Storing bands the same
      # way makes the comparison apples-to-apples by construction, with no
      # conversion at read time and nothing to get wrong. Showing a band in
      # local currency is a display concern.
      t.bigint :min_cents, null: false
      t.bigint :mid_cents, null: false
      t.bigint :max_cents, null: false

      t.timestamps
    end

    # One band per level per country, and the lookup is always by both.
    add_index :pay_bands, %i[job_level_id country_code], unique: true,
              name: "idx_pay_bands_level_country"

    # A band that is not ordered is not a band.
    add_check_constraint :pay_bands,
                         "min_cents > 0 AND min_cents <= mid_cents AND mid_cents <= max_cents",
                         name: "chk_pay_bands_ordered"
  end
end
