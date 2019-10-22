# Performance tests

```
# Run RabbitMQ
docker run -it -p 5672:5672 -p 15672:15672 rabbitmq:3-management

# Then in another terminal 
celery -A tasks worker --loglevel=info -Q my_queue,celery -c 8

# Then run test
ruby test.rb
```

http://docs.celeryproject.org/en/3.0/whatsnew-3.1.html#new-rpc-result-backend

This new experimental version of the amqp result backend is a good alternative to use in classical RPC scenarios, where the process that initiates the task is always the process to retrieve the result.

https://docs.celeryproject.org/en/4.0/whatsnew-4.0.html#features-removed-for-lack-of-funding

The old legacy “amqp” result backend has been deprecated, and will be removed in Celery 5.0.

Please use the rpc result backend for RPC-style calls, and a persistent result backend for multi-consumer results.

https://stackoverflow.com/questions/45974732/celery-rpc-vs-amqp-result-backend

In case of amqp backend, it will create 400 unique queues and stores results in those queues.

In case of rpc backend, it will create only 4 queues(1 per client) and stores 100 results in each queue which results in significant improvement in performance as there is no overhead to create queues for each and every task.

https://docs.celeryproject.org/en/3.1/configuration.html#amqp-backend-settings

Do not use in production.
This is the old AMQP result backend that creates one queue per task, if you want to send results back as message please consider using the RPC backend instead, or if you need the results to be persistent use a result backend designed for that purpose (e.g. Redis, or a database).
