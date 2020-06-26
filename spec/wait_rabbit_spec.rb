RSpec.describe 'wait untill RabbitMQ and Celery start' do
  let(:timeout_sec) { 60 }

  it do
    # Wait Rabbit
    started_at = Time.now
    client = nil

    while client == nil && Time.now - started_at < timeout_sec do
      begin
        client = build_red_celery_client
        expect(client).to be_a RedCelery::Client
      rescue StandardError => e
        sleep(1)
      end
    end

    # Wait Celery
    started_at = Time.now
    result = nil
    task_ids = []
    result_queue = 'result'

    while result == nil && Time.now - started_at < timeout_sec do
      task_ids << client.send_task('tasks.add_task', args: [33, 44], reply_to: result_queue)

      task_ids.each do |task_id|
        if (result ||= client.get_task_result(task_id, result_queue))
          break
        end
      end

      sleep(1)
    end

    expect(result[:result]).to eq 77
  end
end
