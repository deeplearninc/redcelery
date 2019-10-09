from celery import Celery
from time import sleep
import os

broker = 'amqp://guest:guest@localhost:5672/'
# broker = 'amqp://nirkdhgh:HBEkVCv1fz729tFhnHy8WDSCjoS_13pp@eagle.rmq.cloudamqp.com:5672/nirkdhgh'
# backend = local_broker
# backend = 'rpc://'
backend = broker.replace('amqp', 'rpc', 1)
print(backend)

app = Celery('tasks', broker=broker, backend=backend)

@app.task(queue='my_queue')
def add_task(x, y):
  print(str(x) + ' + ' + str(y) + ' = ' + str(x + y))
  return x + y

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
