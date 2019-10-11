RSpec.describe 'multithreaded tasks spawning and results consuming' do
  def report_total_memory(iteration, sent)
    puts "#{iteration}/#{sent}: %d MB" % (`ps -o rss= -p #{Process.pid}`.to_i / 1024)
  end


  def execute_test
    sent = Concurrent::Atom.new(0)
    total = Concurrent::Atom.new(0)
    threads_count = 4
    tasks_per_thread = 50
    timeout = 10

    # Monitor memory usage
    report_thread = Thread.new do
      while true do
        sleep(1)
        report_total_memory(total.value, sent.value)
      end
    end

    task_wo_result_ids = threads_count.times.map do |num|
      Thread.new do
        task_ids = Concurrent::Set.new
        started_at = Time.now

        client = RedCelery::Client.new do |result|
          # p result[:payload]
          task_ids.delete(result[:payload]['task_id'])
          total.swap { |i| i + 1 }
        end

        tasks_per_thread.times do |i|
          task_ids << client.send_task('tasks.add_task', args: [i, 0])
          sent.swap { |i| i + 1 }
        end

        puts 'I"m here'
        puts timeout
        while task_ids.any? && Time.now - started_at < timeout do
          # Do not stop thread until all task results are received
          sleep 1
        end

        puts "Thread ##{num} done!"

        client.close
        task_ids
      end
    end.map(&:join).map(&:value).reduce(:+)

    Thread.kill(report_thread)

    task_wo_result_ids
  end

  it do
    # Check that we receive result for all tasks
    res = execute_test
    expect(res).to be_a Concurrent::Set
    expect(res.size).to eq 0
  end
end
