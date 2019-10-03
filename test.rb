require 'concurrent'
require_relative 'lib/red_celery'

# client = RedCelery::Client.new

def report_total_memory(iteration, lost_task_ids)
  puts "#{iteration}: %d MB" % (`ps -o rss= -p #{Process.pid}`.to_i / 1024)
  puts "#{lost_task_ids}"
end

total = Concurrent::Atom.new(0)
lost_task_ids = Concurrent::Atom.new(Set.new)

mutex = Mutex.new
res = []

THREADS_COUNT = 8
TASKS_PER_THREAD = 1_000

def spawn_task(client, tasks_left, total, lost_task_ids)
  task_id = SecureRandom.uuid
  lost_task_ids.swap { |s| s << task_id }

  client.send_task('my_queue', 'test.add_task', task_args: [tasks_left, 0], task_id: task_id) do |payload|
    lost_task_ids.swap { |s| s.delete(task_id) }
    total.swap { |i| i + 1 }

    if (result = payload['result']) > 0
      spawn_task(client, result - 1, total, lost_task_ids)
    end
  end
end

threads = THREADS_COUNT.times.map do |i|
  Thread.new do
    spawn_task(RedCelery::Client.new, TASKS_PER_THREAD, total, lost_task_ids)
  end
end

while total.value < THREADS_COUNT * TASKS_PER_THREAD do
  sleep(1)
  report_total_memory(total.value, lost_task_ids.value)
end
