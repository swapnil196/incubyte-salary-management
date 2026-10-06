# One period of one employee's pay.
#
# Records are never updated in place. A pay change closes the open record by
# setting effective_to and inserts a new one (ADR 002), so the history is
# complete and every change carries a reason.
#
# effective_to is an exclusive end date. NULL means the record is in force.
class SalaryRecord < ApplicationRecord
  CHANGE_REASONS = %w[
    hire
    merit
    promotion
    market_adjustment
    demotion
    correction
  ].freeze

  belongs_to :employee

  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :base_amount_cents, presence: true,
                                numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true, format: { with: Money::ISO_4217 }
  validates :fx_rate, presence: true, numericality: { greater_than: 0 }
  validates :fx_rate_date, presence: true
  validates :effective_from, presence: true
  validates :change_reason, presence: true, inclusion: { in: CHANGE_REASONS }
  validate :period_must_not_end_before_it_starts

  scope :current, -> { where(effective_to: nil) }
  scope :chronological, -> { order(:effective_from, :id) }
  scope :most_recent_first, -> { order(effective_from: :desc, id: :desc) }

  # Records in force on a given date. effective_to is exclusive.
  scope :in_force_on, lambda { |date|
    where(effective_from: ..date).where("effective_to IS NULL OR effective_to > ?", date)
  }

  def amount = Money.new(amount_cents, currency)

  def base_amount = Money.new(base_amount_cents, BASE_CURRENCY)

  def current? = effective_to.nil?

  private

  def period_must_not_end_before_it_starts
    return if effective_to.blank? || effective_from.blank?
    return if effective_to >= effective_from

    errors.add(:effective_to, "cannot be before the start of the period")
  end
end
