from celery import Celery

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
