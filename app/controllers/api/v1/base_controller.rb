module Api
  module V1
    # Base for every JSON endpoint. Renders JSON only and never falls back to
    # the HTML shell, so a mistyped path fails loudly instead of returning
    # markup the frontend will try to parse.
    class BaseController < ActionController::API
      include BasicAuthGuard

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      private

      def render_not_found(exception)
        render json: { error: { message: exception.message } }, status: :not_found
      end

      def render_unprocessable(message)
        render json: { error: { message: message } }, status: :unprocessable_entity
      end
    end
  end
end
