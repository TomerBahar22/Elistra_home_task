"""RabbitMQ settings shared by the web and the worker (all from environment variables)."""
import os

import pika

QUEUE_NAME = os.getenv("QUEUE_NAME", "weather-requests")
RPC_TIMEOUT = int(os.getenv("RPC_TIMEOUT", "30"))  # seconds the web waits for a worker


def connection_params():
    """connection settings; credentials come from the rabbitmq-default-user Secret"""
    return pika.ConnectionParameters(
        host=os.getenv("RABBITMQ_HOST", "rabbitmq"),
        port=int(os.getenv("RABBITMQ_PORT", "5672")),
        credentials=pika.PlainCredentials(
            os.environ["RABBITMQ_USER"], os.environ["RABBITMQ_PASSWORD"]
        ),
        heartbeat=60,
        blocked_connection_timeout=30,
    )


def declare_queue(channel):
    """durable queue: survives a RabbitMQ restart (messages are also published persistent)"""
    channel.queue_declare(queue=QUEUE_NAME, durable=True)
