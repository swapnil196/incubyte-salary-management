module Api
  module V1
    class EmployeesController < BaseController
      def index
        query = Employees::Query.new(filter_params)
        result = query.call

        render json: {
          data: EmployeeSerializer.list(result.records),
          meta: {
            page: result.page,
            per_page: result.per_page,
            total_count: result.total_count,
            total_pages: result.total_pages,
            sort: query.sort,
            direction: query.direction,
            status: query.status
          }
        }
      end

      private

      def filter_params
        params.permit(:page, :per_page, :q, :sort, :direction, :status,
                      :country_code, :department_id, :job_level_id)
      end
    end
  end
end
