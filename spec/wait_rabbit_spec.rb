RSpec.describe 'wait untill RabbitMQ starts' do
  let(:timeout_sec) { 60 }

  it do
    started_at = Time.now
    client = nil

    while client == nil && Time.now - started_at < timeout_sec do
      begin
        client = RedCelery::Client.new
        expect(client).to be_a RedCelery::Client
      rescue StandardError => e
        sleep(1)
      end
    end
  end
end
