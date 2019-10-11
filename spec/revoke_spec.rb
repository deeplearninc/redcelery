RSpec.describe 'revoking' do
  subject { execute_test }

  let(:timeout_sec) { 10 }

  def execute_test
    client = RedCelery::Client.new
    started_at = Time.now

    task_id = client.send_task('tasks.delay_task', queue: 'my_queue', args: [10])
    client.revoke_task(task_id)

    result = nil
    while result == nil && Time.now - started_at < timeout_sec do
      result = client.get_task_result(task_id)
      sleep 0.5
    end

    client.close
    result
  end

  it do
    expect(subject).to be_a Hash

    expect(subject).to include(
      delivery_info: be_kind_of(Bunny::GetResponse),
      properties: be_kind_of(Bunny::MessageProperties),
      payload: be_kind_of(Hash),
    )

    expect(subject[:payload]['status']).to eq 'REVOKED'
  end
end