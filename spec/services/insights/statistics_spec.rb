require "rails_helper"

RSpec.describe Insights::Statistics do
  describe ".percentile" do
    it "returns nothing for an empty set" do
      expect(described_class.percentile([], described_class::MEDIAN)).to be_nil
    end

    it "returns the only value for a single-element set" do
      expect(described_class.percentile([ 42 ], described_class::P25)).to eq(42)
    end

    it "returns the middle value for an odd-sized set" do
      expect(described_class.median([ 10, 20, 30 ])).to eq(20)
    end

    it "averages the two middle values for an even-sized set" do
      expect(described_class.median([ 10, 20, 30, 40 ])).to eq(25)
    end

    it "interpolates between ranks, matching SQL percentile_cont" do
      # Ranks 0..3 for p25 give 0.75, so three quarters of the way from 10 to 20.
      expect(described_class.percentile([ 10, 20, 30, 40 ], described_class::P25)).to eq(18)
      expect(described_class.percentile([ 10, 20, 30, 40 ], described_class::P75)).to eq(33)
    end

    it "returns the endpoints at the extremes" do
      values = [ 5, 10, 15 ]

      expect(described_class.percentile(values, Rational(0))).to eq(5)
      expect(described_class.percentile(values, Rational(1))).to eq(15)
    end

    it "returns whole cents, never a fraction" do
      result = described_class.median([ 1, 2 ])

      expect(result).to be_an(Integer)
      expect(result).to eq(2) # 1.5 rounds half up
    end

    it "is unaffected by extreme values in a way the mean would not be" do
      # A single very large value moves the mean by thousands and the median
      # not at all. This is the whole reason the dashboard reports medians.
      ordinary = [ 50, 55, 60, 65, 70 ]
      with_executive = [ 50, 55, 60, 65, 10_000 ]

      expect(described_class.median(ordinary)).to eq(60)
      expect(described_class.median(with_executive)).to eq(60)
      expect(with_executive.sum / with_executive.size).to be > 2_000
    end
  end

  describe ".summarise" do
    it "reports headcount with the quartiles, and no mean" do
      result = described_class.summarise([ 30, 10, 20, 40 ])

      expect(result).to eq(headcount: 4, median_cents: 25, p25_cents: 18, p75_cents: 33)
      expect(result).not_to have_key(:mean_cents)
    end

    it "sorts the input itself, so callers cannot get it wrong" do
      expect(described_class.summarise([ 40, 10, 30, 20 ])[:median_cents]).to eq(25)
    end
  end
end
