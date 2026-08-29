ENV['RACK_ENV'] = 'test'

require 'tmpdir'
require 'securerandom'

# Run the whole suite against a throwaway database so the real
# db/wedding.sqlite3 is never touched. app.rb reads this path via WEDDING_DB.
ENV['WEDDING_DB'] = File.join(Dir.tmpdir, "wedding_test_#{SecureRandom.hex(8)}.sqlite3")

require 'minitest/autorun'
require 'rack/test'
require_relative '../app'

# Clean up the throwaway database when the suite finishes.
Minitest.after_run do
  File.delete(ENV['WEDDING_DB']) if ENV['WEDDING_DB'] && File.exist?(ENV['WEDDING_DB'])
end

module TestHelpers
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end
end
