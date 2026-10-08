module Api
  module V1
    class SalaryRecordsController < BaseController
      def create
        employee = Employee.find(params[:employee_id])

        amount = parse_amount
        return render_unprocessable(amount.error) if amount.is_a?(ParseFailure)

        result = Salaries::RecordSalaryChange.call(
          employee: employee,
          amount: amount,
          effective_from: parse_date(salary_params[:effective_from]),
          change_reason: salary_params[:change_reason].to_s,
        )

        if result.success?
          render json: { data: serialize(result.record) }, status: :created
        else
          render_unprocessable(result.error)
        end
      end

      private

      ParseFailure = Data.define(:error)

      def salary_params
        params.require(:salary_record)
              .permit(:amount, :currency, :effective_from, :change_reason)
      end

      # The amount arrives as a string and stays one all the way into Money,
      # which refuses Floats. Parsing it to a Float here would defeat the point
      # of that rule at the one place money enters the system.
      def parse_amount
        Money.from_major(salary_params[:amount].to_s.strip, salary_params[:currency].to_s)
      rescue ArgumentError => e
        ParseFailure.new(error: e.message)
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue Date::Error
        # Left nil so the service reports it alongside any other problem,
        # rather than this controller inventing its own error vocabulary.
        nil
      end

      def serialize(record)
        {
          id: record.id,
          employee_id: record.employee_id,
          amount_cents: record.amount_cents,
          currency: record.currency,
          base_amount_cents: record.base_amount_cents,
          base_currency: BASE_CURRENCY,
          fx_rate: record.fx_rate.to_s("F"),
          fx_rate_date: record.fx_rate_date,
          effective_from: record.effective_from,
          change_reason: record.change_reason
        }
      end
    end
  end
end
