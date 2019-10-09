require 'concurrent'
require 'ruby-prof'
require_relative '../../lib/red_celery'

# RubyProf.measure_mode = RubyProf::ALLOCATIONS
# RubyProf.start

def report_total_memory(iteration, sent)
  puts "#{iteration}/#{sent}: %d MB" % (`ps -o rss= -p #{Process.pid}`.to_i / 1024)
end

sent = Concurrent::Atom.new(0)
total = Concurrent::Atom.new(0)

THREADS_COUNT = 10
TASKS_PER_THREAD = 1000

report_thread = Thread.new do
  while true do
    sleep(1)
    # GC.start(full_mark: true, immediate_sweep: true)
    report_total_memory(total.value, sent.value)
  end
end

def consume_task_results(client, task_ids, total)
  task_ids.delete_if do |task_id|
    if client.get_task_result(task_id)
      task_ids.delete(task_id)
      total.swap { |i| i + 1 }
      true
    end
  end
end

THREADS_COUNT.times.map do |num|
  Thread.new do
    client = RedCelery::Client.new
    task_ids = Set.new

    TASKS_PER_THREAD.times do |i|
      task_ids << client.send_task('test.add_task', queue: 'my_queue', args: [i, 0])
      sent.swap { |i| i + 1 }

      consume_task_results(client, task_ids, total)
    end

    while task_ids.any? do
      consume_task_results(client, task_ids, total)
    end

    client.close
    puts 'Done!'
  end
end.map(&:join)

Thread.kill(report_thread)

# result = RubyProf.stop
# RubyProf::CallTreePrinter.new(result).print()
# RubyProf::FlatPrinter.new(result).print(STDOUT)
