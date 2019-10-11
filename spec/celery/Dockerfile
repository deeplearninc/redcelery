FROM python:3.7-alpine

RUN pip install --no-cache-dir celery==4.3.0

ENV WORKDIR=/var/src/app
WORKDIR $WORKDIR

COPY tasks.py ./

CMD celery -A tasks worker --loglevel=info -Q my_queue,celery -c 8
