module Salaries
  # Records a pay change for one employee.
  #
  # Salary history is append-only (ADR 002): this closes the record currently in
  # force and inserts a new open one, inside a single transaction. Nothing is
  # ever updated in place, so the history stays complete and every change
  # carries a reason.
  #
  # Expected failures (a date before the hire, a missing exchange rate, a bad
  # reason) come back as an unsuccessful Result, because they are things a user
  # can do and the controller needs to render them. Unexpected failures, such as
  # the unique index rejecting a concurrent write, are left to raise.
  class RecordSalaryChange
    Result = Data.define(:record, :error) do
      def success? = error.nil?

      def self.success(record) = new(record: record, error: nil)
      def self.failure(message) = new(record: nil, error: message)
    end

    def self.call(**) = new(**).call

    def initialize(employee:, amount:, effective_from:, change_reason:)
      @employee = employee
      @amount = amount
      @effective_from = effective_from
      @change_reason = change_reason
    end

    def call
      error = validation_error
      return Result.failure(error) if error

      conversion = FxRate.conversion_on(currency: amount.currency, date: effective_from)

      ActiveRecord::Base.transaction do
        close_record_in_force!
        Result.success(open_new_record!(conversion))
      end
    rescue FxRate::RateUnavailable => e
      Result.failure(e.message)
    end

    private

    attr_reader :employee, :amount, :effective_from, :change_reason

    def validation_error
      return "amount must be positive" unless amount.positive?
      return "effective date is missing or not a valid date" if effective_from.blank?
      return "change reason #{change_reason.inspect} is not recognised" unless valid_reason?
      return "effective date cannot be in the future" if effective_from > Date.current
      if effective_from < employee.hired_on
        return "effective date cannot be before the employee was hired on #{employee.hired_on}"
      end
      if record_in_force && effective_from < record_in_force.effective_from
        return "effective date cannot be before the salary currently in force, " \
               "which started on #{record_in_force.effective_from}"
      end

      nil
    end

    def valid_reason? = SalaryRecord::CHANGE_REASONS.include?(change_reason)

    def record_in_force
      return @record_in_force if defined?(@record_in_force)

      @record_in_force = employee.salary_records.current.first
    end

    # Closes the open period. effective_to is exclusive, so setting it to the new
    # start date leaves no gap and no overlap. A same-day change produces a
    # zero-day period, which correctly means that salary never applied.
    def close_record_in_force!
      record_in_force&.update_column(:effective_to, effective_from)
    end

    def open_new_record!(conversion)
      SalaryRecord.create!(
        employee: employee,
        amount_cents: amount.cents,
        currency: amount.currency,
        base_amount_cents: amount.convert_to(BASE_CURRENCY, rate: conversion.rate).cents,
        fx_rate: conversion.rate,
        fx_rate_date: conversion.rate_date,
        effective_from: effective_from,
        change_reason: change_reason,
      )
    end
  end
end
