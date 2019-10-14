from celery import Celery
from time import sleep
import os

broker = 'amqp://guest:guest@localhost:5672/'
backend = 'rpc://'
print(backend)

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
