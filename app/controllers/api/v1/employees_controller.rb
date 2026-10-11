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
            status: query.status,
            band_status: query.band_status
          }
        }
      end

      def export
        exporter = Exports::EmployeesCsv.new(filter_params)

        send_data exporter.call,
                  type: "text/csv; charset=utf-8",
                  filename: exporter.filename,
                  disposition: "attachment"
      end

      def show
        employee = Employee.includes(:department, :job_level, :salary_records)
                           .find(params[:id])

        render json: { data: EmployeeDetailSerializer.new(employee).as_json }
      end

      private

      def filter_params
        params.permit(:page, :per_page, :q, :sort, :direction, :status,
                      :country_code, :department_id, :job_level_id, :band_status)
      end
    end
  end
end
