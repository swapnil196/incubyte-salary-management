# A seniority grade. Ordered by +rank+ rather than by name, because the
# meaningful ordering of "Junior, Mid, Senior, Staff" is not alphabetical.
class JobLevel < ApplicationRecord
  has_many :employees, dependent: :restrict_with_error
  has_many :pay_bands, dependent: :destroy

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :rank, presence: true,
                   numericality: { only_integer: true, greater_than: 0 },
                   uniqueness: true

  scope :by_seniority, -> { order(:rank) }
end
