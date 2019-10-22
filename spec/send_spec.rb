RSpec.describe 'send' do
  let(:timeout_sec) { 5 }

  describe 'with separate result queues' do
    let(:client) { RedCelery::Client.new(rpc_mode: false) }

    subject do
      started_at = Time.now
      task_id = client.send_task('tasks.add_task', queue: queue, args: [11, 22])

      result = nil
      while result == nil && Time.now - started_at < timeout_sec do
        result = client.get_task_result(task_id)
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

  describe 'with shared result queue' do
    subject do
      result = nil

      client = RedCelery::Client.new(rpc_mode: false) do |payload|
        result = payload
      end

      started_at = Time.now
      task_id = client.send_task('tasks.add_task', queue: queue, args: [11, 22])

      result = nil
      while result == nil && Time.now - started_at < timeout_sec do
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
