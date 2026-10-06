require "rails_helper"

RSpec.describe PayBand do
  it { is_expected.to belong_to(:job_level) }

  describe "validations" do
    it "rejects a midpoint below the minimum" do
      band = build(:pay_band, min_cents: 60_000_00, mid_cents: 50_000_00, max_cents: 80_000_00)

      expect(band).not_to be_valid
      expect(band.errors[:mid_cents]).to be_present
    end

    it "rejects a maximum below the midpoint" do
      band = build(:pay_band, min_cents: 50_000_00, mid_cents: 65_000_00, max_cents: 60_000_00)

      expect(band).not_to be_valid
      expect(band.errors[:max_cents]).to be_present
    end

    it "accepts a degenerate band where all three bounds are equal" do
      expect(build(:pay_band, min_cents: 50_000_00, mid_cents: 50_000_00, max_cents: 50_000_00))
        .to be_valid
    end

    it "rejects a second band for the same level and country" do
      level = create(:job_level)
      create(:pay_band, job_level: level, country_code: "DE")

      expect(build(:pay_band, job_level: level, country_code: "DE")).not_to be_valid
    end

    it "allows the same level to have a different band in another country" do
      level = create(:job_level)
      create(:pay_band, job_level: level, country_code: "DE")

      expect(build(:pay_band, job_level: level, country_code: "FR")).to be_valid
    end
  end

  describe "database constraints" do
    it "rejects an unordered band even when validations are bypassed" do
      band = create(:pay_band)

      expect { band.update_column(:mid_cents, 10) }
        .to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe "#position_for" do
    subject(:band) do
      build(:pay_band, min_cents: 50_000_00, mid_cents: 60_000_00, max_cents: 70_000_00)
    end

    def position(major) = band.position_for(Money.from_major(major, BASE_CURRENCY))

    it "reports a compa-ratio of exactly 1 at the midpoint" do
      expect(position("60000").compa_ratio).to eq(BigDecimal("1"))
    end

    it "reports a ratio below 1 for pay under the midpoint" do
      expect(position("54000").compa_ratio).to eq(BigDecimal("0.9"))
    end

    it "reports a ratio above 1 for pay over the midpoint" do
      expect(position("66000").compa_ratio).to eq(BigDecimal("1.1"))
    end

    it "rounds the ratio to four places" do
      # 55,555 / 60,000 = 0.925916666...
      expect(position("55555").compa_ratio).to eq(BigDecimal("0.9259"))
    end

    it "flags pay below the band minimum" do
      result = position("49999")

      expect(result).to be_below_minimum
      expect(result).to be_out_of_band
    end

    it "flags pay above the band maximum" do
      result = position("70001")

      expect(result).to be_above_maximum
      expect(result).to be_out_of_band
    end

    it "treats the minimum itself as inside the band" do
      expect(position("50000")).to be_within_band
    end

    it "treats the maximum itself as inside the band" do
      expect(position("70000")).to be_within_band
    end

    it "refuses to compare an amount in another currency" do
      # A USD salary against a EUR band would produce a plausible, meaningless
      # ratio. Money raises rather than letting that through.
      expect { band.position_for(Money.from_major("60000", "USD")) }
        .to raise_error(Money::CurrencyMismatch)
    end
  end

  describe ".for" do
    it "finds the band for a level and country" do
      level = create(:job_level)
      band = create(:pay_band, job_level: level, country_code: "FR")
      create(:pay_band, job_level: level, country_code: "DE")

      expect(described_class.for(job_level: level, country_code: "FR")).to eq(band)
    end

    it "returns nothing when no band is defined" do
      expect(described_class.for(job_level: create(:job_level), country_code: "JP")).to be_nil
    end
  end
end
