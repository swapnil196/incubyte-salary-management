require "csv"

module Exports
  # Escapes values that a spreadsheet would treat as a formula rather than as
  # text.
  #
  # Excel, LibreOffice and Google Sheets all evaluate a cell beginning with
  # =, +, - or @. A name or department imported from elsewhere that happens to
  # start with one of those characters becomes executable when HR opens the
  # export, and the classic payload is a DDE call that runs a shell command.
  # The export is the attack surface here, not the application.
  #
  # Mitigation is the OWASP one: prefix the cell with a single quote, which
  # spreadsheets strip on display and treat as a text marker.
  module CsvSafe
    DANGEROUS_PREFIXES = [ "=", "+", "-", "@", "\t", "\r" ].freeze

    module_function

    def cell(value)
      # Numbers we formatted ourselves are not user input and must stay numeric,
      # or every amount in the file arrives as text and nothing sums.
      return value if value.is_a?(Numeric)

      string = value.to_s
      return string unless string.start_with?(*DANGEROUS_PREFIXES)

      "'#{string}"
    end

    def row(values) = values.map { |value| cell(value) }
  end
end
