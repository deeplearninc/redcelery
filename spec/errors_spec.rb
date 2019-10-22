RSpec.describe 'errors' do
  let(:client) { RedCelery::Client.new(broker_url: broker_url, rpc_mode: false) }

  context 'not existing vhost' do
    let(:broker_url) { 'amqp://guest:guest@localhost:5672/not_existing_vhost' }

    it do
      expect { client }.to raise_error(RedCelery::Client::VhostNotFoundError)
    end
  end
end
