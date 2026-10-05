# An exact monetary amount: integer minor units plus an ISO 4217 currency.
#
# Two rules this type exists to enforce (ADR 003):
#
#   1. No float ever touches money. Float arguments are rejected by type rather
#      than converted, so `salary * 1.03` fails loudly instead of accumulating
#      binary rounding error across 10,000 rows.
#   2. Currencies never mix silently. Adding EUR to USD raises rather than
#      producing a number that looks plausible and is wrong.
#
# Instances are frozen and compare by value.
class Money
  include Comparable

  class CurrencyMismatch < StandardError; end

  ISO_4217 = /\A[A-Z]{3}\z/
  MINOR_UNITS_PER_MAJOR = 100

  attr_reader :cents, :currency

  def initialize(cents, currency)
    unless cents.is_a?(Integer)
      raise ArgumentError, "amount must be an integer number of minor units, got #{cents.class}"
    end
    unless currency.is_a?(String) && currency.match?(ISO_4217)
      raise ArgumentError, "currency must be a three-letter ISO 4217 code, got #{currency.inspect}"
    end

    @cents = cents
    @currency = currency.freeze
    freeze
  end

  class << self
    # Builds from a major-unit amount: "1234.56" becomes 123456 cents.
    #
    # Accepts String, Integer, BigDecimal and Rational. Rejects Float, because a
    # Float has already lost precision before this method is reached.
    def from_major(amount, currency)
      decimal = to_exact_decimal(amount, "amount")
      new((decimal * MINOR_UNITS_PER_MAJOR).round, currency)
    end

    def zero(currency)
      new(0, currency)
    end

    # Converts to an exact decimal, refusing types that cannot be exact.
    def to_exact_decimal(value, label)
      case value
      when Float
        raise ArgumentError,
              "#{label} must not be a Float: binary floating point cannot represent " \
              "decimal money exactly. Pass a String, Integer or BigDecimal."
      when BigDecimal then value
      when Integer, Rational then BigDecimal(value, 0)
      when String then BigDecimal(value)
      else raise ArgumentError, "#{label} must be numeric, got #{value.class}"
      end
    end
  end

  def +(other)
    assert_same_currency!(other)
    self.class.new(cents + other.cents, currency)
  end

  def -(other)
    assert_same_currency!(other)
    self.class.new(cents - other.cents, currency)
  end

  def -@
    self.class.new(-cents, currency)
  end

  # Scales by a factor, for example a percentage rise. Rounds half up at the
  # minor unit, which is the convention payroll uses.
  def *(other)
    factor = self.class.to_exact_decimal(other, "factor")
    self.class.new((BigDecimal(cents, 0) * factor).round, currency)
  end

  def convert_to(target_currency, rate:)
    exact_rate = self.class.to_exact_decimal(rate, "rate")
    raise ArgumentError, "rate must be positive, got #{exact_rate.to_s('F')}" unless exact_rate.positive?

    self.class.new((BigDecimal(cents, 0) * exact_rate).round, target_currency)
  end

  def zero? = cents.zero?
  def negative? = cents.negative?
  def positive? = cents.positive?

  def to_major
    BigDecimal(cents, 0) / MINOR_UNITS_PER_MAJOR
  end

  def <=>(other)
    return nil unless other.is_a?(self.class)

    assert_same_currency!(other)
    cents <=> other.cents
  end

  def ==(other)
    other.is_a?(self.class) && cents == other.cents && currency == other.currency
  end
  alias eql? ==

  def hash = [ self.class, cents, currency ].hash

  def to_s = format("%.2f %s", to_major, currency)

  def inspect = "#<Money #{self}>"

  private

  def assert_same_currency!(other)
    return if other.is_a?(self.class) && other.currency == currency

    raise CurrencyMismatch,
          "cannot combine #{currency} with #{other.is_a?(self.class) ? other.currency : other.class}"
  end
end
