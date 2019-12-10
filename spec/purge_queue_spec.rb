RSpec.describe 'purge_queue' do
  let(:timeout_sec) { 5 }

  describe 'with shared result queue' do
    ['my_queue', nil, 'not_existing_queue'].each do |queue|
      context "queue = #{queue}" do
        let(:queue) { queue }

        it do
          client = build_red_celery_client { |_payload| }

          client.send_task('tasks.unknown_task', queue: queue, args: [11, 22])

          if queue == 'not_existing_queue'
            expect(client.purge_queue(queue)).to eq false
          else
            expect(client.purge_queue(queue).message_count).to eq 0
          end

          client.close
        end
      end
    end

    context 'purge_queue several queues' do
      it do
        client = build_red_celery_client { |_payload| }

        ['my_queue', nil, 'not_existing_queue'].each do |queue|
          client.send_task('tasks.unknown_task', queue: queue, args: [11, 22])

          expect { client.purge_queue(queue) }.to_not raise_error
        end

        client.close
      end
    end
  end
end
