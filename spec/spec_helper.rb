$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'dblint'
require 'dotenv'
require 'rails'

Dotenv.load

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }
