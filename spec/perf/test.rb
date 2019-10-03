require 'concurrent'
require_relative '../../lib/red_celery'

def report_total_memory(iteration, lost_task_ids)
  puts "#{iteration}: %d MB" % (`ps -o rss= -p #{Process.pid}`.to_i / 1024)
  # puts "#{lost_task_ids}"
end

total = Concurrent::Atom.new(0)
lost_task_ids = Concurrent::Atom.new(Set.new)

mutex = Mutex.new

THREADS_COUNT = 8
TASKS_PER_THREAD = 1_000

def spawn_task(client, i, done_flag, total, lost_task_ids)
  task_id = SecureRandom.uuid
  # lost_task_ids.swap { |s| s << task_id }

  consumer = client.send_task('my_queue', 'test.add_task', task_args: [i, 0], task_id: task_id) do |payload|
    # lost_task_ids.swap { |s| s.delete(task_id) }
    total.swap { |i| i + 1 }
    done_flag.swap { true }
  end
end

# while total.value < THREADS_COUNT * TASKS_PER_THREAD do
report_thread = Thread.new do
  while true do
    sleep(1)
    GC.start(full_mark: true, immediate_sweep: true)
    report_total_memory(total.value, lost_task_ids.value)
  end
end

THREADS_COUNT.times.map do |num|
  Thread.new do
    done_flag = Concurrent::Atom.new(false)
    client = RedCelery::Client.new

    TASKS_PER_THREAD.times do |i|
      spawn_task(client, i, done_flag, total, lost_task_ids)

      while !done_flag.value do
        sleep(0.02)
      end

      done_flag.swap { false }
    end

    puts 'Closing...'
    client.close
    puts 'Done!'
  end
end.map(&:join)

sleep(10)
Thread.kill(report_thread)
