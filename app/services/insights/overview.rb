module Insights
  # Everything the dashboard needs, in two database round trips.
  #
  # Counts and totals are computed by the database. Percentiles are not, because
  # SQLite cannot, so one query projects a single integer column alongside the
  # grouping keys and the distributions are derived from that in Ruby. For the
  # ~9,200 active employees here that is one small result set, not a table scan
  # repeated per dimension.
  class Overview
    # Below this, a breakdown cell can identify one person's pay, so the
    # statistics are withheld and only the headcount is reported. Applied to
    # every dimension, not just pay equity: a department of three is just as
    # identifying as a gender group of three.
    MINIMUM_GROUP_SIZE = 5

    PAY_BAND_JOIN = <<~SQL.squish.freeze
      JOIN pay_bands
        ON pay_bands.job_level_id = employees.job_level_id
       AND pay_bands.country_code = employees.country_code
    SQL

    def self.call(...) = new(...).call

    def initialize(params = {})
      @params = params || {}
    end

    def call
      {
        summary: summary,
        by_country: breakdown { |row| row[:country_code] },
        by_department: breakdown { |row| row[:department] },
        by_level: breakdown(order_by: :rank) { |row| row[:job_level] },
        band_status: band_status,
        pay_equity: pay_equity,
        meta: { base_currency: BASE_CURRENCY, minimum_group_size: MINIMUM_GROUP_SIZE }
      }
    end

    private

    attr_reader :params

    # One row per active employee with a salary in force: the grouping keys and
    # the one number every statistic is derived from.
    def rows
      @rows ||= current_salaries
                .joins(employee: %i[department job_level])
                .pluck(
                  Arel.sql("employees.country_code"),
                  Arel.sql("departments.name"),
                  Arel.sql("job_levels.name"),
                  Arel.sql("job_levels.rank"),
                  Arel.sql("employees.gender"),
                  Arel.sql("salary_records.base_amount_cents"),
                )
                .map do |country, department, level, rank, gender, cents|
                  { country_code: country, department: department, job_level: level,
                    rank: rank, gender: gender, cents: cents }
                end
    end

    def current_salaries
      scope = SalaryRecord.current.joins(:employee).merge(Employee.active)
      scope = scope.where(employees: { country_code: params[:country_code] }) if params[:country_code].present?
      scope = scope.where(employees: { department_id: params[:department_id] }) if params[:department_id].present?
      scope = scope.where(employees: { job_level_id: params[:job_level_id] }) if params[:job_level_id].present?
      scope
    end

    # Summed in SQL rather than over the projected rows. Exact at any size, and
    # it keeps the headline number independent of the sampling the rest of this
    # class does.
    def summary
      total = current_salaries.sum(:base_amount_cents)
      values = rows.map { |row| row[:cents] }

      Statistics.summarise(values).merge(
        annual_payroll_cents: total,
        currency: BASE_CURRENCY,
      )
    end

    def breakdown(order_by: nil)
      grouped = rows.group_by { |row| yield(row) }

      entries = grouped.map do |key, group|
        statistics(group).merge(
          key: key,
          sort_key: order_by ? group.first[order_by] : nil,
        )
      end

      order_by ? entries.sort_by { |e| e[:sort_key] } : entries.sort_by { |e| -e[:headcount] }
    end

    # Withholds the numbers, never the existence of the group. HR still needs to
    # know a country has three people in it; it just cannot see what they earn.
    def statistics(group)
      values = group.map { |row| row[:cents] }
      return { headcount: values.length, suppressed: true } if values.length < MINIMUM_GROUP_SIZE

      Statistics.summarise(values).merge(suppressed: false)
    end

    def band_status
      counts = current_salaries
               .joins(PAY_BAND_JOIN)
               .group(Arel.sql(<<~SQL.squish))
                 CASE
                   WHEN salary_records.base_amount_cents < pay_bands.min_cents THEN 'below_minimum'
                   WHEN salary_records.base_amount_cents > pay_bands.max_cents THEN 'above_maximum'
                   ELSE 'within_band'
                 END
               SQL
               .count

      { below_minimum: counts.fetch("below_minimum", 0),
        within_band: counts.fetch("within_band", 0),
        above_maximum: counts.fetch("above_maximum", 0) }
    end

    # Compared within job level and country, never pooled across the whole
    # organisation. A pooled gap mostly measures who holds the senior roles,
    # which is a real problem but a different one, and conflating them produces
    # a number that cannot be acted on.
    def pay_equity
      rows.group_by { |row| [ row[:job_level], row[:country_code] ] }
          .flat_map { |(level, country), group| equity_cells(level, country, group) }
          .sort_by { |cell| [ cell[:job_level], cell[:country_code], cell[:gender] ] }
    end

    def equity_cells(level, country, group)
      by_gender = group.group_by { |row| row[:gender] }
      reference = by_gender.values.max_by(&:length)
      reference_median = median_for(reference)

      by_gender.map do |gender, people|
        statistics(people).merge(
          job_level: level,
          country_code: country,
          gender: gender,
          difference_from_reference_pct: difference(people, reference_median),
        )
      end
    end

    def median_for(group)
      return nil if group.nil? || group.length < MINIMUM_GROUP_SIZE

      Statistics.median(group.map { |row| row[:cents] }.sort)
    end

    def difference(people, reference_median)
      own = median_for(people)
      return nil if own.nil? || reference_median.nil? || reference_median.zero?

      (((BigDecimal(own, 0) - reference_median) / reference_median) * 100).round(2).to_f
    end
  end
end
