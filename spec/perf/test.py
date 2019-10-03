from celery import Celery

app = Celery('tasks', backend='rpc://', broker='amqp://guest:guest@localhost:5672/')

@app.task(queue='my_queue')
def add_task(x, y):
  print(str(x) + ' + ' + str(y) + ' = ' + str(x + y))
  return x + y

# if __name__ == '__main__':
#   app.worker_main()
