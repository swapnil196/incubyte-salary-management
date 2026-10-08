module Insights
  # Percentiles over integer minor units.
  #
  # SQLite has no percentile_cont (ADR 004), so these are computed in Ruby over
  # a single projected column of integers. At 10,000 rows that column is roughly
  # 80 KB and the whole calculation is microseconds. The threshold at which this
  # stops being reasonable, and the work moves to Postgres, is recorded in the
  # ADR.
  #
  # Fractions are Rationals, not Floats, so the rank arithmetic is exact and the
  # only rounding happens once, at the end, back to whole cents.
  module Statistics
    P25 = Rational(1, 4)
    MEDIAN = Rational(1, 2)
    P75 = Rational(3, 4)

    module_function

    # Linear interpolation between the two neighbouring ranks, matching the
    # behaviour of SQL percentile_cont. For an even-sized set the median is the
    # mean of the two middle values, which is what everyone expects.
    def percentile(sorted_values, fraction)
      return nil if sorted_values.empty?

      size = sorted_values.length
      return sorted_values.first if size == 1

      rank = fraction * (size - 1)
      lower = rank.floor
      upper = rank.ceil
      return sorted_values[lower] if lower == upper

      weight = rank - lower
      ((sorted_values[lower] * (1 - weight)) + (sorted_values[upper] * weight)).round
    end

    def median(sorted_values) = percentile(sorted_values, MEDIAN)

    # The three numbers every breakdown reports. Mean is deliberately absent:
    # pay distributions are right-skewed and a handful of executives drag the
    # mean somewhere nobody is actually paid.
    def summarise(values)
      sorted = values.sort

      {
        headcount: sorted.length,
        median_cents: median(sorted),
        p25_cents: percentile(sorted, P25),
        p75_cents: percentile(sorted, P75)
      }
    end
  end
end
