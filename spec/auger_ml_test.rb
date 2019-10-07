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

client = RedCelery::Client.new

# client.send_task('auger_ml.tasks_queue.tasks.list_project_files_task', task_args: args) do |payload|
# client.send_task('auger_ml.tasks_queue.tasks.get_experiment_configs_task', task_args: args) do |payload|
client.send_task('auger_ml.tasks_queue.evaluate_api.stop_evaluate_task', task_args: args) do |payload|
  puts "-> Got result!!!"
  p payload
  exit
end

sleep 60

client.close
