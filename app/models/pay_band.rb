# The expected pay range for one job level in one country, in BASE_CURRENCY.
#
# Turns a salary from a number into a judgement: this person is paid 8% below
# the midpoint for their level, or below the band entirely.
class PayBand < ApplicationRecord
  STATUSES = %i[below_minimum within_band above_maximum].freeze

  # Where one salary sits against this band.
  #
  # compa_ratio is the standard compensation measure: salary divided by the
  # band midpoint. 1.0 means paid exactly at the midpoint, 0.9 means 10% below
  # it. Rounded to four places, which is more than anyone displays but enough
  # that comparisons do not wobble.
  Position = Data.define(:compa_ratio, :status) do
    def below_minimum? = status == :below_minimum
    def above_maximum? = status == :above_maximum
    def within_band? = status == :within_band
    def out_of_band? = !within_band?
  end

  belongs_to :job_level

  validates :country_code, presence: true,
                           format: { with: Employee::ISO_3166_ALPHA_2 },
                           uniqueness: { scope: :job_level_id,
                                         message: "already has a band for this job level" }
  validates :min_cents, :mid_cents, :max_cents,
            presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :bounds_must_be_ordered

  def self.for(job_level:, country_code:)
    find_by(job_level: job_level, country_code: country_code)
  end

  def minimum = Money.new(min_cents, BASE_CURRENCY)
  def midpoint = Money.new(mid_cents, BASE_CURRENCY)
  def maximum = Money.new(max_cents, BASE_CURRENCY)

  # +amount+ must already be in the base currency, which is what
  # SalaryRecord#base_amount returns. Comparing a local-currency amount against
  # a base-currency band would produce a plausible and meaningless number, so
  # Money raises on the mismatch rather than this method guessing.
  def position_for(amount)
    ratio = (amount.to_major / midpoint.to_major).round(4)

    Position.new(compa_ratio: ratio, status: status_for(amount))
  end

  private

  def status_for(amount)
    return :below_minimum if amount < minimum
    return :above_maximum if amount > maximum

    :within_band
  end

  def bounds_must_be_ordered
    return if [ min_cents, mid_cents, max_cents ].any?(&:blank?)

    errors.add(:mid_cents, "must be at least the minimum") if mid_cents < min_cents
    errors.add(:max_cents, "must be at least the midpoint") if max_cents < mid_cents
  end
end
