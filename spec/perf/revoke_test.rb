require_relative '../../lib/red_celery'

client = RedCelery::Client.new
task_id = client.send_task('test.delay_task', queue: 'my_queue', args: [10])
p client.revoke_task(task_id)

result = nil

while result == nil do
  result = client.get_task_result(task_id)
  sleep 0.5
end

puts "-> Got result!!!"
p result

client.close
