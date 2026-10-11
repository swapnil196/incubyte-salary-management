module Employees
  # Builds the directory listing: filter, search, sort, paginate.
  #
  # Every parameter that reaches SQL is whitelisted rather than sanitised. Sort
  # columns in particular cannot be parameterised by the database driver, so an
  # interpolated sort column is a direct injection route. The allowlist means an
  # unrecognised value is rejected, not escaped and hoped for.
  class Query
    # Public name => the column actually sorted on. Values here are literals in
    # this file; nothing from the request is ever used as a column name.
    SORTABLE = {
      "name" => "employees.last_name, employees.first_name",
      "employee_number" => "employees.employee_number",
      "country" => "employees.country_code",
      "department" => "departments.name",
      "level" => "job_levels.rank",
      "hired_on" => "employees.hired_on",
      "salary" => "salary_records.base_amount_cents",
      "compa_ratio" => "CAST(salary_records.base_amount_cents AS REAL) / pay_bands.mid_cents"
    }.freeze

    DIRECTIONS = %w[asc desc].freeze
    STATUSES = %w[active terminated all].freeze

    # Answers "who is outside their pay band", which the dashboard can only
    # count. Conditions are literals in this file; the request supplies a key,
    # never a fragment.
    #
    # out_of_band is the one HR actually reaches for: both directions at once,
    # because the question is "who needs a conversation", not "who is cheap".
    BAND_STATUS_CONDITIONS = {
      "below_minimum" => "salary_records.base_amount_cents < pay_bands.min_cents",
      "within_band" => "salary_records.base_amount_cents BETWEEN pay_bands.min_cents " \
                       "AND pay_bands.max_cents",
      "above_maximum" => "salary_records.base_amount_cents > pay_bands.max_cents",
      "out_of_band" => "salary_records.base_amount_cents < pay_bands.min_cents " \
                       "OR salary_records.base_amount_cents > pay_bands.max_cents"
    }.freeze

    DEFAULT_SORT = "name"
    DEFAULT_DIRECTION = "asc"
    DEFAULT_STATUS = "active"
    DEFAULT_PER_PAGE = 25
    # A hard ceiling. Without one, ?per_page=999999 is a single request that
    # dumps every salary in the organisation.
    MAX_PER_PAGE = 100

    # Joined rather than associated: the condition spans two columns that live
    # on different tables, which a Rails association cannot express.
    PAY_BAND_JOIN = <<~SQL.squish.freeze
      LEFT JOIN pay_bands
             ON pay_bands.job_level_id = employees.job_level_id
            AND pay_bands.country_code = employees.country_code
    SQL

    Result = Data.define(:records, :total_count, :page, :per_page) do
      def total_pages = per_page.zero? ? 0 : (total_count.to_f / per_page).ceil
    end

    def self.call(...) = new(...).call

    def initialize(params = {})
      @params = params || {}
    end

    def call
      Result.new(
        records: paged_scope,
        total_count: total_count,
        page: page,
        per_page: per_page,
      )
    end

    # Every row matching the filters, with the columns the serializer needs and
    # no pagination. Exposed so the CSV export reuses the exact same filter set
    # rather than reimplementing it.
    def filtered_scope
      apply_filters(decorated_scope).order(Arel.sql(order_clause))
    end

    # Counted against a bare Employee scope rather than the decorated one.
    #
    # Every filter and the search term reference columns on employees alone, so
    # the department, job level, salary and pay band joins contribute nothing
    # to the count and only cost time. Correctness is unaffected either way
    # (all the joins are one-to-at-most-one, so no row multiplication), but
    # this is the query that runs on every page request.
    def total_count
      @total_count ||= apply_filters(count_scope).count
    end

    def page = @page ||= [ params[:page].to_i, 1 ].max

    def per_page
      @per_page ||= begin
        requested = params[:per_page].presence&.to_i || DEFAULT_PER_PAGE
        requested = DEFAULT_PER_PAGE if requested < 1
        [ requested, MAX_PER_PAGE ].min
      end
    end

    def sort = @sort ||= SORTABLE.key?(params[:sort]) ? params[:sort] : DEFAULT_SORT

    def direction
      @direction ||= DIRECTIONS.include?(params[:direction]) ? params[:direction] : DEFAULT_DIRECTION
    end

    def status = @status ||= STATUSES.include?(params[:status]) ? params[:status] : DEFAULT_STATUS

    # nil rather than a default: no band filter is the normal case.
    def band_status
      return @band_status if defined?(@band_status)

      @band_status = BAND_STATUS_CONDITIONS.key?(params[:band_status]) ? params[:band_status] : nil
    end

    private

    attr_reader :params

    def country_code = params[:country_code].presence
    def department_id = params[:department_id].presence
    def job_level_id = params[:job_level_id].presence

    def paged_scope
      filtered_scope.limit(per_page).offset((page - 1) * per_page)
    end

    def apply_filters(scope)
      scope = scope.where(country_code: country_code) if country_code
      scope = scope.where(department_id: department_id) if department_id
      scope = scope.where(job_level_id: job_level_id) if job_level_id
      if band_status
        scope = scope.where(Arel.sql(BAND_STATUS_CONDITIONS.fetch(band_status)))
      end
      apply_search(apply_status(scope))
    end

    # Counting normally needs no joins at all, because every other filter reads
    # columns on employees. A band filter is the exception: it compares the
    # current salary against the band, so both have to be joined in. The page
    # scope already carries them as LEFT JOINs, and the WHERE above gives those
    # inner-join semantics, which is correct — someone with no salary or no band
    # defined has no band status to match.
    def count_scope
      return Employee.all unless band_status

      Employee.joins(:current_salary).joins(PAY_BAND_JOIN)
    end

    def decorated_scope
      Employee
        .joins(:department, :job_level)
        .left_joins(:current_salary)
        .joins(PAY_BAND_JOIN)
        .select(
          "employees.*",
          "departments.name AS department_name",
          "job_levels.name AS job_level_name",
          "job_levels.rank AS job_level_rank",
          "salary_records.amount_cents AS salary_amount_cents",
          "salary_records.currency AS salary_currency",
          "salary_records.base_amount_cents AS salary_base_amount_cents",
          "salary_records.effective_from AS salary_effective_from",
          "pay_bands.min_cents AS band_min_cents",
          "pay_bands.mid_cents AS band_mid_cents",
          "pay_bands.max_cents AS band_max_cents",
        )
    end

    def apply_status(scope)
      case status
      when "active" then scope.active
      when "terminated" then scope.terminated
      else scope
      end
    end

    def apply_search(scope)
      term = params[:q].to_s.strip
      return scope if term.blank?

      # sanitize_sql_like escapes % and _ so a user searching for "100%" looks
      # for that string instead of matching every row.
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"

      scope.where(
        "employees.first_name LIKE :p OR employees.last_name LIKE :p " \
        "OR employees.email LIKE :p OR employees.employee_number LIKE :p",
        p: pattern,
      )
    end

    def order_clause
      column = SORTABLE.fetch(sort)
      # Both halves are drawn from constants in this file, never from the
      # request, so this string cannot carry user input.
      column.split(", ").map { |part| "#{part} #{direction}" }.join(", ") + ", employees.id #{direction}"
    end
  end
end
