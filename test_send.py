from test import add_task
import time

result = add_task.delay(11, 22)

while result.ready() == False:
  time.sleep(0.1)

print(result.get())
