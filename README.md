DjangoToRails
=============
Speeds up ports from Django to Rails

Description
-----------

DjangoToRails speeds up Django-to-Rails application ports by generating Rails models and migrations from provided Django models, all with a single command.  It preserves associations, column definitions, indexes, and more.

Some Django conventions don't have a clear analog in Rails (e.g. Django's auto_now), and notes are printed describing these when the command is run.

Usage
-----

After including djangotorails in the Gemfile of the target Rails app, run the following command to generate the model and migration files in your Rails app, providing the path to your `models.py` as an argument:

    rake djangotorails:run path/to/django/models.py

Shell expansion can be useful, too:

    rake djangotorails:run path/to/django/models/*.py

To perform a dry run, which prints out what the files will look like but doesn't create them, use `djangotorails:test`:

    rake djangotorails:test path/to/django/models.py

Example
-------

For example, given this Django model:

    class Channel(models.Model):
        name = models.CharField(max_length=50)
        sort_name = models.CharField(db_index=True, max_length=50)
        call_sign = models.CharField(db_index=True, max_length=8)
        company = models.ForeignKey(Company)
        genres = models.ManyToManyField(Genre, through='ChannelsGenre')

DjangoToRails will generate this Rails migration:

    # db/migrate/20121030203411_create_channels.rb
    class CreateChannels < ActiveRecord::Migration
      def change
        create_table :channels do |t|
          t.string :name, :length => 50
          t.string :sort_name, :length => 50
          t.string :call_sign, :length => 8
          t.integer :company_id

          t.timestamps
        end

        add_index :channels, :sort_name
        add_index :channels, :call_sign
        add_index :channels, :company_id
      end
    end

And this Rails model:

    # app/models/channel.rb
    class Channel < ActiveRecord::Base
      belongs_to :company
      has_many :channels_genres
      has_many :genres, :through => :channels_genres
    end