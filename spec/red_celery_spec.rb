RSpec.describe RedCelery do
  it 'has a version number' do
    expect(RedCelery::VERSION).not_to be nil
  end

  describe '#declare_queue' do
    let(:client) { build_red_celery_client }

    let(:queue_name) { SecureRandom.hex }

    let(:opts)  do
      {
        exclusive: false,
        auto_delete: true,
        durable: true,
      }
    end

    let(:slightly_different_opts) { opts.merge(durable: false) }

    it do
      queue = client.declare_queue(queue_name, opts)
      expect(queue).to be_a Bunny::Queue
      expect(queue.exclusive?).to eq false
      expect(queue.auto_delete?).to eq true
      expect(queue.durable?).to eq true

      queue = client.declare_queue(queue_name, slightly_different_opts)
      expect(queue).to be_a Bunny::Queue
      expect(queue.exclusive?).to eq false
      expect(queue.auto_delete?).to eq true
      expect(queue.durable?).to eq true
    end
  end
end
