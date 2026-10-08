module Api
  module V1
    # The values the directory filters offer. Small, static, and read on every
    # page load, so it is one endpoint rather than three.
    class ReferencesController < BaseController
      def show
        render json: {
          data: {
            departments: Department.alphabetical.select(:id, :name),
            job_levels: JobLevel.by_seniority.select(:id, :name, :rank),
            # Derived from the data rather than a fixed list: a country with
            # nobody in it is not a useful filter.
            countries: Employee.distinct.order(:country_code).pluck(:country_code),
            change_reasons: SalaryRecord::CHANGE_REASONS,
            currencies: [ BASE_CURRENCY, *FxRate.distinct.order(:currency).pluck(:currency) ].uniq,
            base_currency: BASE_CURRENCY
          }
        }
      end
    end
  end
end
