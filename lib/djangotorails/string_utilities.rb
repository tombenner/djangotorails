module Djangotorails
  module StringUtilities
    def is_numeric?(string)
      true if Float(string) rescue false
    end

    def underscore(string)
      ActiveSupport::Inflector.underscore(string)
    end

    def pluralize(string)
      ActiveSupport::Inflector.pluralize(string)
    end

    def tableize(string)
      ActiveSupport::Inflector.tableize(string)
    end
  end
end