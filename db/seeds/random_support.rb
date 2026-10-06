module Seeds
  # Weighted picks and a log-normal draw, all from one injected generator so the
  # whole dataset is reproducible from a single seed.
  #
  # Floats are used freely here. That is deliberate and not a contradiction of
  # the no-floats-near-money rule: these produce a *distribution*, and every
  # value is rounded to an integer number of cents at the moment it becomes
  # money. Nothing stored or summed is ever a float.
  module RandomSupport
    module_function

    def weighted(rng, options, key: :weight)
      total = options.sum { |o| o.fetch(key) }
      target = rng.rand * total

      cumulative = 0.0
      options.each do |option|
        cumulative += option.fetch(key)
        return option if target < cumulative
      end
      options.last
    end

    # Box-Muller. Ruby has no normal distribution in the standard library and
    # pulling a statistics gem in to seed fake data is not worth the dependency.
    def normal(rng, mean: 0.0, sd: 1.0)
      u1 = 1.0 - rng.rand
      u2 = rng.rand
      mean + (Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2) * sd)
    end

    # Pay within a level clusters near the midpoint with a longer tail upwards,
    # which is what a log-normal gives and a uniform draw does not. A uniform
    # spread would make every median land suspiciously close to every midpoint.
    def lognormal_factor(rng, sd: 0.11)
      Math.exp(normal(rng, mean: 0.0, sd: sd))
    end

    def date_between(rng, from, to)
      span = (to - from).to_i
      return from if span <= 0

      from + rng.rand(span + 1)
    end
  end
end
