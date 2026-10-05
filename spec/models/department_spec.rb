require "rails_helper"

RSpec.describe Department do
  it { is_expected.to validate_presence_of(:name) }

  it "rejects a duplicate name regardless of casing" do
    create(:department, name: "Engineering")

    duplicate = build(:department, name: "engineering")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  describe ".alphabetical" do
    it "orders by name" do
      create(:department, name: "Sales")
      create(:department, name: "Engineering")

      expect(described_class.alphabetical.pluck(:name)).to eq(%w[Engineering Sales])
    end
  end
end
