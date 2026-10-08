require "rails_helper"

RSpec.describe Exports::CsvSafe do
  describe ".cell" do
    it "leaves ordinary text alone" do
      expect(described_class.cell("Engineering")).to eq("Engineering")
    end

    it "leaves numbers numeric, so the spreadsheet can still sum them" do
      expect(described_class.cell(70_000)).to eq(70_000)
      expect(described_class.cell(-5)).to eq(-5)
    end

    # Each of these is evaluated as a formula by Excel, LibreOffice and Google
    # Sheets. The classic payload is a DDE call that runs a shell command on
    # the machine of whoever opens the file.
    %w[= + - @].each do |prefix|
      it "neutralises a cell starting with #{prefix.inspect}" do
        payload = "#{prefix}cmd|' /C calc'!A0"

        expect(described_class.cell(payload)).to eq("'#{payload}")
      end
    end

    it "neutralises leading tab and carriage return" do
      expect(described_class.cell("\t=1+1")).to eq("'\t=1+1")
      expect(described_class.cell("\r=1+1")).to eq("'\r=1+1")
    end

    it "does not touch a dangerous character that is not leading" do
      expect(described_class.cell("Research = Development")).to eq("Research = Development")
    end

    it "handles nil" do
      expect(described_class.cell(nil)).to eq("")
    end
  end

  describe ".row" do
    it "escapes every cell that needs it and leaves the rest" do
      expect(described_class.row([ "Ada", "=HYPERLINK(\"http://x\")", 42 ]))
        .to eq([ "Ada", "'=HYPERLINK(\"http://x\")", 42 ])
    end
  end
end
