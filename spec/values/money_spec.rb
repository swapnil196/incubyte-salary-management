require "rails_helper"

RSpec.describe Money do
  describe "construction" do
    it "holds integer minor units and a currency" do
      money = described_class.new(123_456, "EUR")

      expect(money.cents).to eq(123_456)
      expect(money.currency).to eq("EUR")
    end

    it "is frozen, so it cannot be mutated after construction" do
      expect(described_class.new(100, "EUR")).to be_frozen
    end

    it "rejects a non-integer amount" do
      expect { described_class.new(100.5, "EUR") }.to raise_error(ArgumentError, /integer/i)
      expect { described_class.new("100", "EUR") }.to raise_error(ArgumentError, /integer/i)
    end

    it "rejects anything that is not a three-letter ISO 4217 code" do
      expect { described_class.new(100, "eur") }.to raise_error(ArgumentError, /ISO 4217/)
      expect { described_class.new(100, "EU") }.to raise_error(ArgumentError, /ISO 4217/)
      expect { described_class.new(100, nil) }.to raise_error(ArgumentError, /ISO 4217/)
    end

    it "accepts negative amounts, because a correction can reduce pay" do
      expect(described_class.new(-5_000, "EUR").cents).to eq(-5_000)
    end
  end

  describe ".from_major" do
    it "converts a decimal string to minor units" do
      expect(described_class.from_major("1234.56", "EUR").cents).to eq(123_456)
    end

    it "converts a whole number" do
      expect(described_class.from_major(1_234, "EUR").cents).to eq(123_400)
    end

    it "converts a BigDecimal" do
      expect(described_class.from_major(BigDecimal("99.99"), "EUR").cents).to eq(9_999)
    end

    it "rounds half up at the minor unit" do
      expect(described_class.from_major("0.005", "EUR").cents).to eq(1)
      expect(described_class.from_major("0.004", "EUR").cents).to eq(0)
    end

    it "refuses a Float outright" do
      # 0.1 + 0.2 != 0.3 in binary floating point. Accepting a Float here would
      # let that error in through the front door, so the type is rejected
      # rather than silently converted.
      expect { described_class.from_major(1234.56, "EUR") }
        .to raise_error(ArgumentError, /Float/)
    end
  end

  describe ".zero" do
    it "builds a zero amount in the given currency" do
      zero = described_class.zero("USD")

      expect(zero.cents).to eq(0)
      expect(zero).to be_zero
      expect(zero.currency).to eq("USD")
    end
  end

  describe "arithmetic" do
    let(:ten_euro) { described_class.new(1_000, "EUR") }
    let(:five_euro) { described_class.new(500, "EUR") }

    it "adds two amounts in the same currency" do
      expect((ten_euro + five_euro).cents).to eq(1_500)
    end

    it "subtracts two amounts in the same currency" do
      expect((ten_euro - five_euro).cents).to eq(500)
    end

    it "negates" do
      expect((-ten_euro).cents).to eq(-1_000)
    end

    it "refuses to add two different currencies" do
      expect { ten_euro + described_class.new(500, "USD") }
        .to raise_error(Money::CurrencyMismatch, /EUR.*USD/)
    end

    it "refuses to subtract two different currencies" do
      expect { ten_euro - described_class.new(500, "USD") }
        .to raise_error(Money::CurrencyMismatch)
    end

    it "multiplies by an integer" do
      expect((ten_euro * 3).cents).to eq(3_000)
    end

    it "multiplies by a BigDecimal and rounds half up" do
      # A 3% rise on 1000.00 is 1030.00
      expect((ten_euro * BigDecimal("1.03")).cents).to eq(1_030)
      # 2.5 rounds to 3, not to 2
      expect((described_class.new(5, "EUR") * BigDecimal("0.5")).cents).to eq(3)
    end

    it "refuses to multiply by a Float" do
      expect { ten_euro * 1.03 }.to raise_error(ArgumentError, /Float/)
    end
  end

  describe "comparison" do
    it "treats equal amounts in the same currency as equal" do
      expect(described_class.new(100, "EUR")).to eq(described_class.new(100, "EUR"))
    end

    it "treats the same number in different currencies as not equal" do
      expect(described_class.new(100, "EUR")).not_to eq(described_class.new(100, "USD"))
    end

    it "orders amounts in the same currency" do
      expect(described_class.new(200, "EUR")).to be > described_class.new(100, "EUR")
      expect([ described_class.new(300, "EUR"), described_class.new(100, "EUR") ].min.cents).to eq(100)
    end

    it "refuses to order across currencies rather than comparing the raw numbers" do
      expect { described_class.new(100, "EUR") < described_class.new(100, "USD") }
        .to raise_error(Money::CurrencyMismatch)
    end

    it "hashes equal values together, so Money works as a Hash key" do
      a = described_class.new(100, "EUR")
      b = described_class.new(100, "EUR")

      expect({ a => :found }[b]).to eq(:found)
    end
  end

  describe "#convert_to" do
    it "applies the rate and rounds half up" do
      hundred_usd = described_class.new(10_000, "USD")

      converted = hundred_usd.convert_to("EUR", rate: BigDecimal("0.925"))

      expect(converted.currency).to eq("EUR")
      expect(converted.cents).to eq(9_250)
    end

    it "rounds to the nearest minor unit rather than truncating" do
      converted = described_class.new(101, "USD").convert_to("EUR", rate: BigDecimal("0.925"))

      # 101 * 0.925 = 93.425, which rounds to 93
      expect(converted.cents).to eq(93)
    end

    it "refuses a Float rate" do
      expect { described_class.new(100, "USD").convert_to("EUR", rate: 0.925) }
        .to raise_error(ArgumentError, /Float/)
    end

    it "rejects a non-positive rate" do
      expect { described_class.new(100, "USD").convert_to("EUR", rate: BigDecimal("0")) }
        .to raise_error(ArgumentError, /positive/)
    end
  end

  describe "#to_major" do
    it "returns an exact decimal, never a float" do
      major = described_class.new(123_456, "EUR").to_major

      expect(major).to be_a(BigDecimal)
      expect(major).to eq(BigDecimal("1234.56"))
    end
  end

  describe "#to_s" do
    it "renders the amount with its currency" do
      expect(described_class.new(123_456, "EUR").to_s).to eq("1234.56 EUR")
      expect(described_class.new(-50, "USD").to_s).to eq("-0.50 USD")
    end
  end
end
