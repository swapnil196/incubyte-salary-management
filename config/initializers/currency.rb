# The single currency every salary is normalised into for company-wide
# reporting. Individual salaries are stored and displayed in local currency;
# only aggregates use this one.
#
# Changing this after data exists would invalidate every stored
# base_amount_cents, so it is a constant rather than a setting.
BASE_CURRENCY = "EUR".freeze
