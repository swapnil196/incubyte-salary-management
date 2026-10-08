module Api
  module V1
    class InsightsController < BaseController
      def show
        render json: { data: Insights::Overview.call(insight_params) }
      end

      private

      def insight_params
        params.permit(:country_code, :department_id, :job_level_id)
      end
    end
  end
end
