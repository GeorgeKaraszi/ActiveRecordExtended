# frozen_string_literal: true

class Regexp
  # Stripped from ActiveSupport v5.1
  unless //.respond_to?(:match?)
    def match?(string, pos = 0)
      !(!match(string, pos))
    end
  end
end
