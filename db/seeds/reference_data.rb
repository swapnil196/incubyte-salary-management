require_relative "catalog"

module Seeds
  # Departments, job levels, exchange rates and pay bands. Small tables, created
  # with ordinary ActiveRecord so validations still run, then handed back as
  # lookup hashes for the bulk employee insert to reference by id.
  class ReferenceData
    RATE_DATE = Date.new(2026, 1, 1).freeze

    def self.call(...) = new(...).call

    def initialize(logger: $stdout)
      @logger = logger
    end

    def call
      departments = create_departments
      job_levels = create_job_levels
      create_fx_rates
      create_pay_bands(job_levels)

      { departments: departments, job_levels: job_levels }
    end

    private

    attr_reader :logger

    def create_departments
      Catalog::DEPARTMENTS.to_h do |attrs|
        [ attrs[:name], Department.create!(name: attrs[:name]) ]
      end.tap { logger.puts "  #{Catalog::DEPARTMENTS.size} departments" }
    end

    def create_job_levels
      Catalog::JOB_LEVELS.to_h do |attrs|
        [ attrs[:name], JobLevel.create!(name: attrs[:name], rank: attrs[:rank]) ]
      end.tap { logger.puts "  #{Catalog::JOB_LEVELS.size} job levels" }
    end

    def create_fx_rates
      rates = Catalog::COUNTRIES
              .reject { |c| c[:currency] == BASE_CURRENCY }
              .uniq { |c| c[:currency] }

      rates.each do |country|
        FxRate.create!(currency: country[:currency], base_currency: BASE_CURRENCY,
                       rate: BigDecimal(country[:rate]), rate_date: RATE_DATE)
      end
      logger.puts "  #{rates.size} exchange rates"
    end

    # One band per level per country, in BASE_CURRENCY, scaled by local cost.
    def create_pay_bands(job_levels)
      bands = Catalog::JOB_LEVELS.flat_map do |level|
        Catalog::COUNTRIES.map do |country|
          mid = (level[:midpoint] * BigDecimal(country[:cost_factor]) * 100).round

          {
            job_level_id: job_levels.fetch(level[:name]).id,
            country_code: country[:code],
            min_cents: (mid * Catalog::BAND_MIN_FACTOR).round,
            mid_cents: mid,
            max_cents: (mid * Catalog::BAND_MAX_FACTOR).round
          }
        end
      end

      PayBand.insert_all!(bands, record_timestamps: true)
      logger.puts "  #{bands.size} pay bands"
    end
  end
end
