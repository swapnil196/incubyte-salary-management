require "rails_helper"

RSpec.describe FxRate do
  it { is_expected.to validate_presence_of(:rate_date) }

  it "requires three-letter ISO 4217 codes" do
    expect(build(:fx_rate, currency: "US")).not_to be_valid
    expect(build(:fx_rate, currency: "usd")).not_to be_valid
    expect(build(:fx_rate, currency: "USD")).to be_valid
  end

  it "rejects a rate of zero or less" do
    expect(build(:fx_rate, rate: 0)).not_to be_valid
    expect(build(:fx_rate, rate: -1)).not_to be_valid
  end

  it "rejects a second rate for the same currency on the same date" do
    create(:fx_rate, currency: "USD", rate_date: Date.new(2026, 3, 1))

    expect(build(:fx_rate, currency: "USD", rate_date: Date.new(2026, 3, 1))).not_to be_valid
  end

  describe ".rate_on" do
    it "returns exactly 1 for the base currency without touching the database" do
      expect(described_class.rate_on(currency: BASE_CURRENCY, date: Date.new(2026, 3, 1)))
        .to eq(BigDecimal(1))
    end

    it "returns the rate published on the date itself" do
      create(:fx_rate, currency: "USD", rate: BigDecimal("0.90"), rate_date: Date.new(2026, 3, 1))

      expect(described_class.rate_on(currency: "USD", date: Date.new(2026, 3, 1)))
        .to eq(BigDecimal("0.90"))
    end

    it "falls back to the most recent rate still in force" do
      create(:fx_rate, currency: "USD", rate: BigDecimal("0.90"), rate_date: Date.new(2026, 1, 1))
      create(:fx_rate, currency: "USD", rate: BigDecimal("0.95"), rate_date: Date.new(2026, 3, 1))

      # 15 March: the March rate is in force, the January one is superseded.
      expect(described_class.rate_on(currency: "USD", date: Date.new(2026, 3, 15)))
        .to eq(BigDecimal("0.95"))
    end

    it "ignores rates published after the date, so backdated records convert correctly" do
      create(:fx_rate, currency: "USD", rate: BigDecimal("0.90"), rate_date: Date.new(2026, 1, 1))
      create(:fx_rate, currency: "USD", rate: BigDecimal("0.95"), rate_date: Date.new(2026, 3, 1))

      expect(described_class.rate_on(currency: "USD", date: Date.new(2026, 2, 1)))
        .to eq(BigDecimal("0.90"))
    end

    it "raises rather than guessing when no rate has been published yet" do
      create(:fx_rate, currency: "USD", rate_date: Date.new(2026, 3, 1))

      expect { described_class.rate_on(currency: "USD", date: Date.new(2026, 1, 1)) }
        .to raise_error(FxRate::RateUnavailable, /USD to #{BASE_CURRENCY}/)
    end

    it "raises for a currency it has never seen" do
      expect { described_class.rate_on(currency: "JPY", date: Date.new(2026, 3, 1)) }
        .to raise_error(FxRate::RateUnavailable)
    end
  end
end
