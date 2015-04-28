class Minion < ActiveRecord::Base
  has_many :dodos, counter_cache: true
end

class Dodo < ActiveRecord::Base
  belongs_to :minion, touch: true
  belongs_to :kitten
end

class Kitten < ActiveRecord::Base
  has_many :dodos
  has_many :minions, through: :dodos
end

RSpec.configure do |config|
  config.after(:suite) do
    # :sad_panda:
    Minion.delete_all
    Dodo.delete_all
    Kitten.delete_all
  end
end
