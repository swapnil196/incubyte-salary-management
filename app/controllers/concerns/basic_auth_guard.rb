# HTTP Basic authentication for the deployed instance only (ADR 005).
#
# This is NOT the authentication that was scoped out, and must not be mistaken
# for it. There is still no user model, no session and no concept of a role.
# This exists so that a demo instance carrying 10,000 realistic salary records
# is not readable by anyone who finds the URL.
#
# Inactive unless BASIC_AUTH_PASSWORD is set, so development and the test suite
# are unaffected.
module BasicAuthGuard
  extend ActiveSupport::Concern

  included do
    # ActionController::API does not carry these by default, unlike ::Base, and
    # this concern is mixed into both hierarchies.
    include ActionController::HttpAuthentication::Basic::ControllerMethods

    before_action :require_basic_auth
  end

  private

  def require_basic_auth
    expected_password = ENV["BASIC_AUTH_PASSWORD"]
    return if expected_password.blank?

    expected_username = ENV.fetch("BASIC_AUTH_USERNAME", "hr")

    authenticate_or_request_with_http_basic("Salary Management") do |username, password|
      # Single & rather than &&: both comparisons always run, so the response
      # time does not reveal whether the username alone was correct.
      ActiveSupport::SecurityUtils.secure_compare(username.to_s, expected_username) &
        ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_password)
    end
  end
end
