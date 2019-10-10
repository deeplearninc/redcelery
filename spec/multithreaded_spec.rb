RSpec.describe 'multithreaded tasks spawning and results consuming' do
  subject { execute_test }

  TIMEOUT_SEC = 10
  THREADS_COUNT = 4
  TASKS_PER_THREAD = 50

  def report_total_memory(iteration, sent)
    puts "#{iteration}/#{sent}: %d MB" % (`ps -o rss= -p #{Process.pid}`.to_i / 1024)
  end

  def execute_test
    sent = Concurrent::Atom.new(0)
    total = Concurrent::Atom.new(0)

    # Monitor memory usage
    report_thread = Thread.new do
      while true do
        sleep(1)
        report_total_memory(total.value, sent.value)
      end
    end

    task_wo_result_ids = THREADS_COUNT.times.map do |num|
      Thread.new do
        task_ids = Concurrent::Set.new
        started_at = Time.now

        client = RedCelery::Client.new do |result|
          task_ids.delete(result[:payload]['task_id'])
          total.swap { |i| i + 1 }
        end

        TASKS_PER_THREAD.times do |i|
          task_ids << client.send_task('tasks.add_task', args: [i, 0])
          sent.swap { |i| i + 1 }
        end

        while task_ids.any? && Time.now - started_at < TIMEOUT_SEC do
          # Do not stop thread until all task results are received
          sleep 1
        end

        client.close
        task_ids
      end
    end.map(&:join).map(&:value).reduce(:+)

    Thread.kill(report_thread)

    task_wo_result_ids
  end

  it do
    # Check that we receive result for all tasks
    expect(subject).to be_a Concurrent::Set
    expect(subject).to be_empty
  end
end
