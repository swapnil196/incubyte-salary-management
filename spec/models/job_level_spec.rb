require "rails_helper"

RSpec.describe JobLevel do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:rank) }

  it "requires rank to be a positive integer" do
    expect(build(:job_level, rank: 0)).not_to be_valid
    expect(build(:job_level, rank: -1)).not_to be_valid
    expect(build(:job_level, rank: 1)).to be_valid
  end

  it "rejects a duplicate rank, so seniority order stays unambiguous" do
    create(:job_level, rank: 3)

    expect(build(:job_level, rank: 3)).not_to be_valid
  end

  describe ".by_seniority" do
    it "orders by rank rather than alphabetically" do
      create(:job_level, name: "Senior", rank: 3)
      create(:job_level, name: "Junior", rank: 1)
      create(:job_level, name: "Mid",    rank: 2)

      expect(described_class.by_seniority.pluck(:name)).to eq(%w[Junior Mid Senior])
    end
  end
end
