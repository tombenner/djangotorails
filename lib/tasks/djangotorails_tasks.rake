require File.expand_path("../../djangotorails", __FILE__)

namespace :djangotorails do
  desc "Creates Rails models and migrations from Django models (e.g. rake djangotorails path/to/django/models.py)"
  task :run do
    args = ARGV
    args.shift
    django_to_rails = Djangotorails::Base.new
    django_to_rails.run({:input_files => args})
  end

  desc "Performs a dry run of the creation Rails models and migrations from Django models (e.g. rake djangotorails path/to/django/models.py)"
  task :test do
    args = ARGV
    args.shift
    django_to_rails = Djangotorails::Base.new
    django_to_rails.run({:input_files => args, :debug => true})
  end
end