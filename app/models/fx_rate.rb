# An exchange rate published on a given date.
#
# +rate+ is how many units of +base_currency+ one unit of +currency+ buys, so
# converting is a multiplication: amount_in_base = amount * rate.
#
# Rates are stored rather than fetched live. A report re-run next quarter has to
# return the number it returned today, and a test has to be able to run without
# a network (ADR 003).
class FxRate < ApplicationRecord
  class RateUnavailable < StandardError; end

  ISO_4217 = /\A[A-Z]{3}\z/

  validates :currency, :base_currency,
            presence: true,
            format: { with: ISO_4217, message: "must be a three-letter ISO 4217 code" }
  validates :rate, presence: true, numericality: { greater_than: 0 }
  validates :rate_date, presence: true
  # The unique index is the real guard against duplicates; this validation
  # exists to turn the race into a readable error in the common case.
  validates :currency, uniqueness: { scope: %i[base_currency rate_date] }

  # The rate actually applied, together with the date it was published.
  #
  # Both are stored on the salary record, so a conversion can be explained and
  # reproduced later: "60,000 USD at 0.92, published 1 March" rather than an
  # unattributable number.
  Conversion = Data.define(:rate, :rate_date)

  # The conversion in force for +currency+ on +date+.
  #
  # Rates are published irregularly, so "the rate on 3 March" normally means the
  # rate published on 1 March and not yet superseded. Hence most-recent-on-or-
  # before rather than an exact date match.
  def self.conversion_on(currency:, date:, base: BASE_CURRENCY)
    return Conversion.new(rate: BigDecimal(1), rate_date: date) if currency == base

    row = where(currency: currency, base_currency: base)
          .where(rate_date: ..date)
          .order(rate_date: :desc)
          .first

    unless row
      raise RateUnavailable, "No #{currency} to #{base} rate published on or before #{date}"
    end

    Conversion.new(rate: row.rate, rate_date: row.rate_date)
  end

  def self.rate_on(currency:, date:, base: BASE_CURRENCY)
    conversion_on(currency: currency, date: date, base: base).rate
  end
end
