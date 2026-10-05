class CreateFxRates < ActiveRecord::Migration[8.1]
  def change
    create_table :fx_rates do |t|
      t.string :currency, null: false, limit: 3
      t.string :base_currency, null: false, limit: 3
      # How many units of base_currency one unit of currency is worth.
      # Scale 8 because thinly traded pairs need the precision, and rounding
      # happens once at the point of conversion rather than in storage.
      t.decimal :rate, precision: 18, scale: 8, null: false
      t.date :rate_date, null: false

      t.timestamps
    end

    # Supports the only lookup there is: the most recent rate for a currency on
    # or before a given date. Leading columns match the equality predicates and
    # the trailing date column serves the range scan and the ordering, so the
    # query is satisfied by the index alone.
    add_index :fx_rates, %i[currency base_currency rate_date], unique: true,
              name: "idx_fx_rates_lookup"
  end
end
