require_relative "catalog"
require_relative "random_support"

module Seeds
  # Generates the employee population and its salary history.
  #
  # Two things matter here beyond "make 10,000 rows":
  #
  # Determinism. Everything is drawn from one injected Random, so the same seed
  # produces byte-identical data. A demo that looks different on every run is
  # impossible to talk about, and a test against generated data would be flaky.
  #
  # Throughput. 10,000 employees carry roughly 26,000 salary records. Creating
  # those one at a time through ActiveRecord means ~36,000 INSERTs plus
  # validation and callback overhead, which runs into minutes. Batched
  # insert_all! brings it to seconds. Reference data is small enough to create
  # normally, so validations still cover it.
  class Workforce
    include RandomSupport

    DEFAULT_COUNT = 10_000
    BATCH_SIZE = 1_000
    TERMINATION_RATE = 0.08
    MAX_RAISES = 3

    # Deliberately planted so the exceptions report has something to find. A
    # dashboard that flags outliers cannot be demonstrated, or tested, against
    # data that contains none.
    BELOW_BAND_RATE = 0.025
    ABOVE_BAND_RATE = 0.015

    # Also deliberately planted, for the same reason: the pay equity view exists
    # to surface a gap, so the sample data has to contain one. These factors are
    # an arbitrary fiction chosen to make the feature demonstrable and testable.
    # They are not a claim about any real organisation.
    GENDER_PAY_FACTOR = { "female" => 0.96, "non_binary" => 0.97 }.freeze

    def self.call(...) = new(...).call

    def initialize(reference:, count: DEFAULT_COUNT, seed: 20_261_006, today: Date.current,
                   logger: $stdout)
      @departments = reference.fetch(:departments)
      @job_levels = reference.fetch(:job_levels)
      @count = count
      @rng = Random.new(seed)
      @today = today
      @logger = logger
      @bands = PayBand.pluck(:job_level_id, :country_code, :mid_cents)
                      .to_h { |level_id, country, mid| [ [ level_id, country ], mid ] }
      @salary_id = 0
      Faker::Config.random = Random.new(seed)
    end

    def call
      (1..count).each_slice(BATCH_SIZE) do |ids|
        employees = []
        salaries = []

        ids.each do |id|
          employee = build_employee(id)
          employees << employee
          salaries.concat(build_salary_history(employee))
        end

        # _country and _level are carried through generation for the salary
        # builder and are not columns.
        Employee.insert_all!(employees.map { |e| e.except(:_country, :_level) },
                             record_timestamps: true)
        SalaryRecord.insert_all!(salaries, record_timestamps: true)
      end

      logger.puts "  #{count} employees"
      logger.puts "  #{SalaryRecord.count} salary records"
    end

    private

    attr_reader :departments, :job_levels, :count, :rng, :today, :logger, :bands

    def build_employee(id)
      country = weighted(rng, Catalog::COUNTRIES)
      level = weighted(rng, Catalog::JOB_LEVELS)
      department = weighted(rng, Catalog::DEPARTMENTS)
      gender = weighted(rng, Catalog::GENDERS)[:value]

      first_name = Faker::Name.first_name
      last_name = Faker::Name.last_name
      hired_on = date_between(rng, today - (10 * 365), today - 30)
      terminated_on = termination_for(hired_on)

      {
        id: id,
        employee_number: format("ACME-%05d", id),
        first_name: first_name,
        last_name: last_name,
        email: email_for(first_name, last_name, id),
        country_code: country[:code],
        department_id: departments.fetch(department[:name]).id,
        job_level_id: job_levels.fetch(level[:name]).id,
        gender: gender,
        hired_on: hired_on,
        terminated_on: terminated_on,
        # Carried for the salary generator; stripped before insert.
        _country: country,
        _level: level
      }.freeze
    end

    def termination_for(hired_on)
      return nil unless rng.rand < TERMINATION_RATE

      earliest = hired_on + 90
      # Someone hired in the last three months has not had time to leave.
      return nil if earliest > today

      date_between(rng, earliest, today)
    end

    def email_for(first_name, last_name, id)
      slug = "#{first_name}.#{last_name}".downcase.gsub(/[^a-z.]/, "")
      "#{slug}.#{id}@acme.example"
    end

    # Builds the full history for one employee, forwards from the hire date.
    #
    # The target is the *current* salary, drawn from the band. Earlier amounts
    # are derived by dividing back through the raises, so the person ends up
    # where the distribution says they should and got there plausibly.
    def build_salary_history(employee)
      country = employee[:_country]
      hired_on = employee[:hired_on]
      ends_on = employee[:terminated_on]

      raise_dates = raise_dates_for(hired_on, ends_on)
      raise_factors = Array.new(raise_dates.size) { 1.0 + (0.03 + (rng.rand * 0.09)) }

      final_base = target_base_cents(employee)
      starting_base = (final_base / raise_factors.reduce(1.0, :*)).round

      amounts = [ starting_base ]
      raise_factors.each_with_index do |_, index|
        amounts << (starting_base * raise_factors[0..index].reduce(1.0, :*)).round
      end

      dates = [ hired_on, *raise_dates ]
      reasons = [ "hire", *Array.new(raise_dates.size) { weighted(rng, Catalog::CHANGE_REASONS)[:value] } ]

      dates.each_with_index.map do |effective_from, index|
        salary_record(
          employee: employee,
          country: country,
          base_cents: amounts[index],
          effective_from: effective_from,
          # Exclusive end: the next period's start, or the termination date for
          # someone who has left. A terminated employee has no open record,
          # which is both correct and what keeps them out of payroll totals.
          effective_to: dates[index + 1] || ends_on,
          change_reason: reasons[index],
        )
      end
    end

    def raise_dates_for(hired_on, ends_on)
      last_possible = ends_on || today
      dates = []
      cursor = hired_on + rng.rand(300..480)

      while cursor < last_possible && dates.size < MAX_RAISES
        dates << cursor
        cursor += rng.rand(330..540)
      end

      dates
    end

    def target_base_cents(employee)
      midpoint = bands.fetch([ employee[:job_level_id], employee[:country_code] ])
      factor = lognormal_factor(rng) * GENDER_PAY_FACTOR.fetch(employee[:gender], 1.0)

      draw = rng.rand
      factor = Catalog::BAND_MIN_FACTOR * (0.80 + (rng.rand * 0.15)) if draw < BELOW_BAND_RATE
      if draw > 1.0 - ABOVE_BAND_RATE
        factor = Catalog::BAND_MAX_FACTOR * (1.02 + (rng.rand * 0.15))
      end

      [ (midpoint * factor).round, 1_00 ].max
    end

    # Converts the base-currency target into the employee's local currency and
    # back, so amount_cents and base_amount_cents are consistent with the stored
    # rate rather than independently rounded.
    def salary_record(employee:, country:, base_cents:, effective_from:, effective_to:,
                      change_reason:)
      rate = BigDecimal(country[:rate])
      local_cents = (BigDecimal(base_cents, 0) / rate).round

      @salary_id += 1
      {
        id: @salary_id,
        employee_id: employee[:id],
        amount_cents: local_cents,
        currency: country[:currency],
        base_amount_cents: (BigDecimal(local_cents, 0) * rate).round,
        fx_rate: rate,
        fx_rate_date: ReferenceData::RATE_DATE,
        effective_from: effective_from,
        effective_to: effective_to,
        change_reason: change_reason
      }
    end
  end
end
