require 'bundler/setup'
require 'red_celery'
require 'concurrent'

Dir['spec/support/**/*.rb'].each { |f| require f.sub('spec/', '') }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.threadsafe = true
end

def rpc_mode
  ENV.fetch('RPC_MODE', 'true') == 'true'
end

def build_red_celery_client(options = {}, &block)
  RedCelery::Client.new(rpc_mode: rpc_mode, **options, &block)
end

puts "Use #{rpc_mode ? "RPC" : "AMQP"} mode"
