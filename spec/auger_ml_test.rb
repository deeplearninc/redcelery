require 'concurrent'
require_relative '../lib/red_celery'

args = [
  {
    "augerInfo": {
      "experiment_id": "77feed1e3668dfb4",
      "dataset_manifest_id": "2b6e477322733998",
      "experiment_session_id": "80f5854a08d4918d"
    },
    "data_path": "s3://auger-mt-org-cinpns/workspace/projects/dk-exp-ts/files/bts-jpy.csv",
    "content_type": "text/csv",
    "data_extension": ".csv",
    "data_compression": "infer"
  }
]

client = RedCelery::Client.new(rpc_mode: false)

p task_id = client.send_task('auger_ml.tasks_queue.tasks.list_project_files_task', args: args)
# client.send_task('auger_ml.tasks_queue.tasks.get_experiment_configs_task', args: args) do |payload|
# client.send_task('auger_ml.tasks_queue.tasks.evaluate_start_task', args: args) do |payload|
# task_id = client.send_task('auger_ml.tasks_queue.evaluate_api.get_leaderboard_task', args: args)
# task_id = client.send_task('auger_ml.tasks_queue.evaluate_api.stop_evaluate_task', args: args)
# p task_id = client.send_task('auger_ml.tasks_queue.tasks.datasource_get_statistics_task', args: args) # FAILURE

result = nil

while result == nil do
  result = client.get_task_result(task_id)
  sleep 0.5
end

puts "-> Got result!!!"
p result

client.close
