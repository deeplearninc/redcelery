from celery import Celery
from kombu import Exchange, Queue
from time import sleep
import os

broker = 'amqp://guest:guest@localhost:5672/'
backend = 'rpc://'

app = Celery('tasks', broker=broker, backend=backend)

@app.task(queue='my_queue')
def log_task(data):
  print('Logged data: ' + str(data))

@app.task(queue='my_queue')
def sub_add_task(x, y):
  return x + 1, y + 1

@app.task(queue='my_queue')
def add_task(x, y):
  # x, y = sub_add_task.apply_async(args=[x, y], priority=10).get(disable_sync_subtasks=False)
  res = x + y
  log_task.delay(str(x) + ' + ' + str(y) + ' = ' + str(res))
  return res

@app.task(queue='my_queue')
def delay_task(period_s):
  print('Sleeping for ' + str(period_s) + ' sec')
  sleep(period_s)
  return period_s

@app.task(queue='my_queue')
def test_revoke(period_s):
  print('Test revoke')
  res = delay_task.apply_async(args=[period_s])
  sleep(1)
  res.revoke(terminate=True)
  sleep(120)
  return res

@app.task(queue='my_queue')
def test_fail(value):
  return value / 0

@app.task(queue='alt_queue', name='alt_tasks.mult_task')
def mult_task(x, y):
  # x, y = sub_add_task.apply_async(args=[x, y], priority=10).get(disable_sync_subtasks=False)
  res = x * y
  log_task.delay(str(x) + ' * ' + str(y) + ' = ' + str(res))
  return res

# app.conf.task_queues = (
#     Queue('my_queue', routing_key='tasks.#', priority=3),
#     Queue('alt_queue', routing_key='alt_queue', priority=3),
# )

app.conf.task_routes = {
    'tasks.*': {'queue': 'my_queue'},
    'alt_tasks.*': {'queue': 'alt_queue'},
    # 'tasks.add_task': {'queue': 'my_queue'},
    # 'tasks.delay_task': {'queue': 'my_queue'},
    # 'tasks.log_task': {'queue': 'my_queue'},
    # 'tasks.sub_add_task': {'queue': 'my_queue'},
    # 'tasks.test_fail': {'queue': 'my_queue'},
    # 'tasks.test_revoke': {'queue': 'my_queue'},

    # 'tasks.mult_task': {'queue': 'alt_queue'},
}
