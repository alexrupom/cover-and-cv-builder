require 'bundler/setup'
$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'cvgen'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = :random
  Kernel.srand config.seed
end

FIXTURES_DIR = File.join(__dir__, 'fixtures')

def fixture_path(name)
  File.join(FIXTURES_DIR, name)
end

def fixture(name)
  File.read(fixture_path(name), encoding: 'UTF-8')
end

def fixture_json(name)
  JSON.parse(fixture(name))
end
