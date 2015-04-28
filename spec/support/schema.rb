RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Base.establish_connection ENV['DATABASE_URL']

    ActiveRecord::Schema.define do
      self.verbose = false

      create_table :minions, force: true do |t|
        t.string :name
        t.timestamps null: false
      end

      create_table :dodos, force: true do |t|
        t.references :minion
        t.references :kitten
        t.timestamps null: false
      end

      create_table :kittens, force: true do |t|
        t.string :name
        t.timestamps null: false
      end
    end
  end
end
