$:.push File.expand_path("..", __FILE__)

module Djangotorails
  autoload :Base,             "djangotorails/base"
  autoload :StringUtilities,  "djangotorails/string_utilities"
end