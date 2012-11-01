# N.B.: This was written as a one-off script for a single project, and it could use a great
# deal of improvement on many levels (to start off, it should use generators).

module Djangotorails
  class Base
    include Djangotorails::StringUtilities

    def initialize
      reset
    end

    def reset
      @input_files = []
      @models = []
      @messages = []
      @debug = false
    end

    def run(options)
      reset
      defaults = {
        :debug => false,
        :input_files => []
      }
      options.reverse_merge(defaults)

      @debug = options[:debug]
      options[:input_files].each do |file|
        @input_files << file
      end
      @input_files.compact!
      raise "Please specify a Django model file" if @input_files.empty?

      set_models
      create_migrations
      create_models

      @messages.each do |message|
        puts message
      end
    end

    def set_models
      @input_files.each do |file_name|
        @models += get_models_from_file(file_name)
      end
      @models.collect do |model|
        model[:rails] = convert_django_model_to_rails_model(model[:django])
        model
      end
    end

    def create_migrations
      now = Time.now
      i = 0
      @models.each do |model|
        content = get_migration_file_content_from_model(model[:rails])
        timestamp = (now + i).strftime("%Y%m%d%H%M%S")
        write_file("db/migrate/#{timestamp}_create_#{tableize(model[:rails][:name])}.rb", content)
        i += 1
      end
    end

    def create_models
      @models.each do |model|
        content = get_model_file_content_from_model(model[:rails])
        write_file("app/models/#{underscore(model[:rails][:name])}.rb", content)
      end
    end

    def get_models_from_file(file_name)
      content = File.open(file_name, "rb").read
      model_matches = content.scan(/class ([\w]+)\(models.Model(?:[^\)]*)\)\:\s*\n(.*?)\n\n/m)
      models = []
      model_matches.each do |model_match|
        class_name = model_match[0]
        class_definition = model_match[1]
        fields = get_fields_from_class_definition(class_definition)
        models << {
          django: {
            name: class_name,
            fields: fields
          }
        }
      end
      models
    end

    def convert_django_model_to_rails_model(django_model)
      rails_model = {
        name: django_model[:name],
        table: tableize(django_model[:name]),
        fields: [],
        associations: []
      }
      omitted_fields = ["created_at", "updated_at"]
      django_model[:fields].each do |django_field|
        next if omitted_fields.include?(django_field[:name])
        field = convert_django_field_to_rails_field(django_model, django_field)
        if field
          rails_model[:fields] << field
        end
      end
      rails_model[:associations] = get_rails_associations_from_django_model(django_model)
      rails_model
    end

    def convert_django_field_to_rails_field(django_model, django_field)
      rails_field = {
        name: django_field[:name],
        arguments: {}
      }
      case django_field[:type]
        when "AutoField"
          rails_field[:type] = :integer
          @messages << "#{django_model[:name]}##{django_field[:name]} is an AutoField, which may need to be accounted for in the model."
        when "BigIntegerField"
          rails_field[:type] = :integer
          rails_field[:arguments][:limit] = 8
        when "BooleanField"
          rails_field[:type] = :boolean
          rails_field[:null] = false
        when "CharField"
          rails_field[:type] = :string
        when "DateField"
          rails_field[:type] = :date
        when "DateTimeField"
          rails_field[:type] = :datetime
        when "DecimalField"
          rails_field[:type] = :decimal
        when "EmailField"
          rails_field[:type] = :string
          @messages << "#{django_model[:name]}##{django_field[:name]} is an EmailField, which may need to be accounted for in the model."
        when "FileField"
          rails_field[:type] = :string
          @messages << "#{django_model[:name]}##{django_field[:name]} is a FileField, which may need to be accounted for in the model."
        when "FilePathField"
          rails_field[:type] = :string
          @messages << "#{django_model[:name]}##{django_field[:name]} is a FilePathField, which may need to be accounted for in the model."
        when "FloatField"
          rails_field[:type] = :float
        when "GenericIPAddressField"
          rails_field[:type] = :string
          @messages << "#{django_model[:name]}##{django_field[:name]} is a GenericIPAddressField, which may need to be accounted for in the model."
        when "IntegerField"
          rails_field[:type] = :integer
        when "IPAddressField"
          rails_field[:type] = :string
          @messages << "#{django_model[:name]}##{django_field[:name]} is an IPAddressField, which may need to be accounted for in the model."
        when "NullBooleanField"
          rails_field[:type] = :boolean
          rails_field[:null] = true
        when "PositiveIntegerField"
          rails_field[:type] = :integer
          @messages << "#{django_model[:name]}##{django_field[:name]} is unsigned"
        when "PositiveSmallIntegerField"
          rails_field[:type] = :integer
          rails_field[:arguments][:limit] = 3
          @messages << "#{django_model[:name]}##{django_field[:name]} is unsigned"
        when "SlugField"
          rails_field[:type] = :string
          rails_field[:has_index] = true
          rails_field[:arguments][:limit] = 50
        when "SmallIntegerField"
          rails_field[:type] = :integer
          rails_field[:arguments][:limit] = 3
        when "TextField"
          rails_field[:type] = :text
        when "TimeField"
          rails_field[:type] = :time
        when "URLField"
          rails_field[:type] = :string
          @messages << "#{django_model[:name]}##{django_field[:name]} is a URLField, which may need to be accounted for in the model."
        when "ForeignKey"
          rails_field[:type] = :integer
          rails_field[:name] = "#{django_field[:name]}_id"
          rails_field[:has_index] = true
        when "ManyToManyField"
          # This is handled by adding a has_many :through association in the model's file
          return nil
        when "OneToOneField"
          rails_field[:type] = :integer
          rails_field[:name] = "#{django_field[:name]}_id"
          rails_field[:has_index] = true
        else
          @messages << "Couldn\'t determine a Rails type for #{django_model[:name]}##{django_field[:name]}"
      end

      if django_field[:arguments][:named].has_key?(:db_column)
        rails_field[:name] = django_field[:arguments][:named][:db_column]
      end
      if django_field[:arguments][:named].has_key?(:db_index)
        rails_field[:has_index] = django_field[:arguments][:named][:db_index] == "True" ? true : false
      end
      if django_field[:arguments][:named].has_key?(:default)
        rails_field[:arguments][:default] = convert_django_argument_string_to_rails_value(django_field[:arguments][:named][:default])
      end
      if django_field[:arguments][:named].has_key?(:null)
        if django_field[:arguments][:named][:null] == "False" && rails_field[:arguments].has_key?(:null)
          rails_field[:arguments][:null] = false
        end
      end
      if django_field[:arguments][:named].has_key?(:unique)
        rails_field[:is_unique] = convert_django_argument_string_to_rails_value(django_field[:arguments][:named][:unique])
      end

      if rails_field[:type] == :decimal
        if django_field[:arguments][:named].has_key?(:max_digits)
          rails_field[:arguments][:precision] = convert_django_argument_string_to_rails_value(django_field[:arguments][:named][:max_digits])
        end
        if django_field[:arguments][:named].has_key?(:decimal_places)
          rails_field[:arguments][:scale] = convert_django_argument_string_to_rails_value(django_field[:arguments][:named][:decimal_places])
        end
      end
      if rails_field[:type] == :string
        if django_field[:arguments][:named].has_key?(:max_length)
          rails_field[:arguments][:limit] = convert_django_argument_string_to_rails_value(django_field[:arguments][:named][:max_length])
        end
      end
      if django_field[:arguments][:named].has_key?(:auto_now)
        @messages << "#{django_model[:name]}##{django_field[:name]} is `auto_now`. This should be set to `Time.now` in a callback in the model."
      end

      rails_field
    end

    def get_rails_associations_from_django_model(django_model)
      associations = {}
      django_model[:fields].each do |field|
        if ["ForeignKey", "OneToOneField"].include?(field[:type])
          associations[:belongs_to] ||= {}
          options = {}
          if field[:arguments][:unnamed].length == 1
            class_name = field[:arguments][:unnamed][0]
            if tableize(field[:name]) != tableize(class_name)
              options[:class_name] = "\"#{class_name}\""
            end
          end
          associations[:belongs_to][field[:name].to_sym] = options
        elsif field[:type] == "ManyToManyField"
          associations[:has_many] ||= {}
          options = {}
          if field[:arguments][:named].has_key?(:through)
            through = tableize(convert_django_argument_string_to_rails_value(field[:arguments][:named][:through])).to_sym
            options[:through] = through
            associations[:has_many][through] = {}
          end
          associations[:has_many][field[:name].to_sym] = options
        end
      end
      associations
    end

    def convert_django_argument_string_to_rails_value(string)
      case string
        when "True"
          return true
        when "False"
          return false
        when "None"
          return nil
      end
      if is_numeric?(string)
        if string =~ /[\d]+/
          return Integer(string)
        else
          return Float(string)
        end
      end
      if string =~ /^'(.*?)'$/
        return $1
      end
      if string =~ /^"(.*?)"$/
        return $1
      end
      @messages << "Unable to convert \"#{string}\" to a valid value"
      return string
    end

    def get_migration_file_content_from_model(model)
      class_name = "Create#{pluralize(model[:name])}"
      table_name = model[:table]

      field_lines = []
      model[:fields].each do |field|
        line = "      t.#{field[:type]} :#{field[:name]}"
        if !field[:arguments].empty?
          line << ", #{convert_hash_to_rails_arguments_string(field[:arguments])}"
        end
        field_lines << line
      end
      field_lines = field_lines.empty? ? "" : field_lines.join("\n")+"\n"

      index_lines = []
      model[:fields].each do |field|
        if field.has_key?(:has_index) && field[:has_index]
          index_lines << "    add_index :#{table_name}, :#{field[:name]}"
        end
      end
      index_lines = index_lines.empty? ? "" : "\n"+index_lines.join("\n")+"\n"

      content = <<-EOF
class #{class_name} < ActiveRecord::Migration
  def change
    create_table :#{table_name} do |t|
#{field_lines}
      t.timestamps
    end
#{index_lines}  end
end
EOF
    end

    def get_model_file_content_from_model(model)
      class_name = model[:name]
      association_lines = []
      model[:associations].each do |association_type, associations|
        associations.each do |association_name, association|
          line = "  #{association_type} :#{association_name}"
          if !association.empty?
            line << ", #{convert_hash_to_rails_arguments_string(association)}"
          end
          association_lines << line
        end
      end
      association_lines = association_lines.empty? ? "" : association_lines.join("\n")+"\n"
      content = <<-EOF
class #{class_name} < ActiveRecord::Base
#{association_lines}end
EOF
    end

    def get_fields_from_class_definition(class_definition)
      field_matches = class_definition.scan(/([\w]+) = models.([\w]+)\(([\w\s_=,'"]*)/)
      fields = []
      field_matches.each do |field_match|
        field = {
          name: field_match[0],
          type: field_match[1]
        }
        field[:arguments] = get_arguments_from_string(field_match[2])
        fields << field
      end
      fields
    end

    def get_arguments_from_string(string)
      argument_matches = string.split(/,\s+/)
      arguments = {
        named: {},
        unnamed: []
      }
      argument_matches.each do |argument_match|
        argument_split = argument_match.split("=")
        if argument_split.length == 2
          arguments[:named][argument_split[0].to_sym] = argument_split[1]
        else
          arguments[:unnamed] << argument_match
        end
      end
      arguments
    end

    def convert_hash_to_rails_arguments_string(hash)
      arguments = hash.collect do |k, v|
        v = v.is_a?(Symbol) ? ":#{v}" : v
        ":#{k} => #{v}"
      end
      arguments.join(", ")
    end

    def write_file(path, content)
      if @debug
        puts "---------------------------------------------"
        puts "#{path} will contain:"
        puts content
      else
        path = Rails.root.join(*(path.split("/")))
        File.open(path, 'w'){ |f| f.write(content) }
        puts "Wrote #{path}"
      end
    end
  end
end