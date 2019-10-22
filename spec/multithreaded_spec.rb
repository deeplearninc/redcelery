RSpec.describe 'multithreaded tasks spawning and results consuming' do
  def report_total_memory(iteration, sent)
    puts "#{iteration}/#{sent}: %d MB Threads: #{Thread.list.count}" % (`ps -o rss= -p #{Process.pid}`.to_i / 1024)
  end

  def execute_test
    sent = Concurrent::Atom.new(0)
    total = Concurrent::Atom.new(0)
    task_ids = Concurrent::Set.new
    threads_count = 4
    tasks_per_thread = 50
    timeout = 10

    # Monitor memory usage
    report_thread = Thread.new do
      while true do
        report_total_memory(total.value, sent.value)
        sleep(0.25)
      end
    end

    client = RedCelery::Client.new(rpc_mode: false) do |result|
      task_ids.delete(result[:task_id])
      total.swap { |i| i + 1 }
    end

    threads_count.times.map do |num|
      Thread.new do
        started_at = Time.now

        tasks_per_thread.times do |i|
          task_ids << client.send_task('tasks.add_task', args: [i, 0])
          sent.swap { |i| i + 1 }
        end

        while task_ids.any? && Time.now - started_at < timeout do
          # Do not stop thread until all task results are received
          sleep 1
        end

        puts "Thread ##{num} done!"
      end
    end.map(&:join)

    client.close
    Thread.kill(report_thread)

    task_ids
  end

  it do
    # Check that we receive result for all tasks
    res = execute_test
    expect(res).to be_a Concurrent::Set
    expect(res.size).to eq 0
  end
end
