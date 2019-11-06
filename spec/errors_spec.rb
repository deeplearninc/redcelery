RSpec.describe 'errors' do
  let(:client) { build_red_celery_client(broker_url: broker_url) }

  context 'not existing vhost' do
    let(:broker_url) { 'amqp://guest:guest@localhost:5672/not_existing_vhost' }

    it do
      expect { client }.to raise_error(RedCelery::Client::VhostNotFoundError)
    end
  end
end
