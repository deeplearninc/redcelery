# Performance tests

```
# Run RabbitMQ
docker run -it -p 5672:5672 -p 15672:15672 rabbitmq:3-management

# Then in another terminal 
celery -A test worker --loglevel=info -Q my_queue

# Then run test
ruby test.rb
```
