$:.push File.expand_path("../lib", __FILE__)

require "djangotorails/version"

Gem::Specification.new do |s|
  s.name        = "djangotorails"
  s.version     = Djangotorails::VERSION
  s.authors     = ["Tom Benner"]
  s.email       = ["tombenner@gmail.com"]
  s.homepage    = "https://github.com/tombenner/djangotorails"
  s.summary     = "Generate Rails models and migrations from Django models"
  s.description = "Generate Rails models and migrations from Django models"

  s.files = `git ls-files`.split("\n")#Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.7"
end
