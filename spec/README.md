# Performance tests

```
# Run RabbitMQ
docker run -it -p 5672:5672 -p 15672:15672 rabbitmq:3-management

# Then in another terminal 
celery -A tasks worker --loglevel=info -Q my_queue,celery -c 8

# Then run test
ruby test.rb
```
