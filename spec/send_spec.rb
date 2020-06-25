RSpec.describe 'send' do
  let(:timeout_sec) { 5 }

  describe 'with separate result queues' do
    let(:client) { build_red_celery_client }

    subject do
      started_at = Time.now
      result_queue = SecureRandom.hex

      task_id = client.send_task(
        'tasks.add_task',
        queue: queue,
        args: [11, 22],
        queue_opts: { durable: true },
        reply_to: result_queue
      )

      expect(client.connection).to be_open

      result = nil
      while result == nil && Time.now - started_at < timeout_sec do
        result = client.get_task_result(task_id, result_queue)
        sleep 0.5
      end

      client.close
      result
    end

    ['my_queue', nil].each do |queue|
      context "queue = #{queue}" do
        let(:queue) { queue }

        it do
          expect(subject).to be_a Hash

          expect(subject).to be_kind_of(Hash)
          expect(subject[:status]).to eq 'SUCCESS'
          expect(subject[:result]).to eq 33
        end
      end
    end
  end
end
