class Employee < ApplicationRecord
  ISO_3166_ALPHA_2 = /\A[A-Z]{2}\z/
  GENDERS = %w[female male non_binary undisclosed].freeze

  belongs_to :department
  belongs_to :job_level

  has_many :salary_records, dependent: :destroy

  # The salary currently in force. Declared as an association rather than a
  # method so the directory can eager-load it and avoid an N+1 across 10,000
  # rows. Backed by the partial unique index, so there is never more than one.
  has_one :current_salary,
          -> { where(effective_to: nil) },
          class_name: "SalaryRecord",
          inverse_of: :employee,
          dependent: nil

  validates :employee_number, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :country_code, presence: true,
                           format: { with: ISO_3166_ALPHA_2,
                                     message: "must be a two-letter ISO 3166-1 code" }
  validates :hired_on, presence: true
  validates :gender, inclusion: { in: GENDERS }, allow_nil: true
  validate :termination_cannot_precede_hire

  scope :active, -> { where(terminated_on: nil) }
  scope :terminated, -> { where.not(terminated_on: nil) }
  scope :in_country, ->(code) { where(country_code: code) }

  # Everything a directory row needs, without an N+1 per employee.
  scope :with_directory_associations, -> { includes(:department, :job_level, :current_salary) }

  def full_name = "#{first_name} #{last_name}"

  # The band this employee is measured against.
  #
  # Single-record lookup only. Bulk paths must join pay_bands on
  # (job_level_id, country_code) in SQL rather than calling this per row, or
  # they issue one query per employee.
  def pay_band = PayBand.for(job_level: job_level, country_code: country_code)

  def active? = terminated_on.nil?

  # The salary in force on a given date, which is not necessarily the current
  # one. effective_to is exclusive, so a record ending on the date asked about
  # has already been superseded.
  def salary_on(date)
    salary_records
      .where(effective_from: ..date)
      .where("effective_to IS NULL OR effective_to > ?", date)
      .first
  end

  private

  def termination_cannot_precede_hire
    return if terminated_on.blank? || hired_on.blank?
    return if terminated_on >= hired_on

    errors.add(:terminated_on, "cannot be before the hire date")
  end
end
