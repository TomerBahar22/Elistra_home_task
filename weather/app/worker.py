"""Worker: takes weather requests from RabbitMQ, calls the weather API,
sends the result back to the waiting web pod, then acknowledges.

KEDA scales this Deployment by the number of messages waiting in the queue.
"""
import json
import logging
import os
import signal
import sys
import time

import pika

from queue_config import QUEUE_NAME, connection_params, declare_queue
from weather import get_weather

logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s %(levelname)s worker: %(message)s")
log = logging.getLogger("worker")
logging.getLogger("pika").setLevel(logging.WARNING)  # pika is very chatty at INFO

# Artificial extra processing time, to make the queue build up visibly in a demo
WORK_DELAY = float(os.getenv("WORK_DELAY", "0"))


def on_request(channel, method, props, body):
    """process one request; ack only AFTER replying, so a worker that dies
    mid-request (e.g. scaled down by KEDA) leaves it to be redelivered"""
    try:
        location = json.loads(body)["location"]
    except (ValueError, KeyError):
        log.warning("dropping malformed message")
        channel.basic_ack(delivery_tag=method.delivery_tag)
        return

    log.info("lookup: %s", location)
    data = get_weather(location)
    if WORK_DELAY:
        time.sleep(WORK_DELAY)

    if props.reply_to:
        channel.basic_publish(
            exchange="",
            routing_key=props.reply_to,
            properties=pika.BasicProperties(correlation_id=props.correlation_id),
            body=json.dumps({"data": data}),
        )
    channel.basic_ack(delivery_tag=method.delivery_tag)


def handle_sigterm(signum, frame):
    """Kubernetes sends SIGTERM before stopping the pod. Exiting closes the
    connection; any un-acked message goes back to the queue automatically."""
    log.info("SIGTERM received, shutting down")
    sys.exit(0)


def main():
    signal.signal(signal.SIGTERM, handle_sigterm)

    while True:  # reconnect loop: RabbitMQ may not be ready yet, or may restart
        try:
            connection = pika.BlockingConnection(connection_params())
            channel = connection.channel()
            declare_queue(channel)
            channel.basic_qos(prefetch_count=1)  # one message at a time per worker
            channel.basic_consume(queue=QUEUE_NAME, on_message_callback=on_request)
            log.info("waiting for requests on '%s'", QUEUE_NAME)
            channel.start_consuming()
        except pika.exceptions.AMQPConnectionError as e:
            log.warning("RabbitMQ not reachable (%s), retrying in 5s", type(e).__name__)
            time.sleep(5)


if __name__ == "__main__":
    main()
