require "dotenv"

Dotenv.load

require "webmock/rspec"
require "handlers"

RSpec.configure do |c|
  c.before do
    allow(STDOUT).to receive(:puts)
  end
end
