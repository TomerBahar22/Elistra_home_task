"""Web: search page + autocomplete.

The slow part (calling the weather API) is done by workers.
Each lookup is sent to RabbitMQ as a request, and the web waits for the
worker's reply (RPC / request-reply), so the page behaves exactly as before.
"""
import json
import logging
import uuid

import geonamescache
import pika
from flask import Flask, render_template, request

from queue_config import QUEUE_NAME, RPC_TIMEOUT, connection_params, declare_queue

app = Flask(__name__)
app.logger.setLevel(logging.INFO)

# requests from the kubelet probes and the ALB health check - too noisy to log
HEALTH_CHECK_AGENTS = ("kube-probe", "ELB-HealthChecker")

# Log every real request (skips health checks and static files)
@app.after_request
def log_request(response):
    """log every real request (skips health checks and static files)"""
    agent = request.headers.get("User-Agent", "")
    if not (agent.startswith(HEALTH_CHECK_AGENTS) or request.path.startswith("/static")):
        app.logger.info("%s %s -> %s", request.method, request.path, response.status_code)
    return response

# Send a weather lookup request to the queue and wait for a worker's reply.
def request_weather(location):
    """send a lookup to the queue and wait for a worker's reply.

    Uses RabbitMQ 'direct reply-to': the reply comes back on a pseudo-queue
    tied to this connection, so no temporary queue is created per request.
    Returns the forecast dict, or None on error / timeout.
    """
    correlation_id = str(uuid.uuid4())
    result = {}

    def on_reply(ch, method, props, body):
        if props.correlation_id == correlation_id:
            result["reply"] = json.loads(body)

    connection = pika.BlockingConnection(connection_params())
    try:
        channel = connection.channel()
        declare_queue(channel)
        channel.basic_consume(queue="amq.rabbitmq.reply-to",
                              on_message_callback=on_reply, auto_ack=True)
        channel.basic_publish(
            exchange="",
            routing_key=QUEUE_NAME,
            body=json.dumps({"location": location}),
            properties=pika.BasicProperties(
                reply_to="amq.rabbitmq.reply-to",
                correlation_id=correlation_id,
                delivery_mode=pika.DeliveryMode.Persistent,
                # nobody waits after the timeout: let RabbitMQ drop stale requests
                expiration=str(RPC_TIMEOUT * 1000),
            ),
        )
        connection.process_data_events(time_limit=0)
        waited = 0.0
        while "reply" not in result and waited < RPC_TIMEOUT:
            connection.process_data_events(time_limit=0.5)
            waited += 0.5
    finally:
        connection.close()

    reply = result.get("reply")
    if reply is None:
        app.logger.warning("no worker reply within %ss for: %s", RPC_TIMEOUT, location)
        return None
    return reply.get("data")


@app.route("/", methods=["GET", "POST"])
def home():
    """render the search page; on POST, look up weather by coordinates
    (if a suggestion was picked) or by the typed city name as fallback"""
    weather_data = None
    error = None

    if request.method == "POST":
        lat = request.form.get("lat", "").strip()
        lon = request.form.get("lon", "").strip()
        city = request.form.get("city", "").strip()

        if lat and lon:  # user picked a suggestion -> exact coordinates
            weather_location = f"{lat},{lon}"
        elif city:
            weather_location = city
        else:
            weather_location = None
            error = "Please enter a city or country."

        if weather_location:
            app.logger.info("weather lookup: %s", weather_location)
            try:
                weather_data = request_weather(weather_location)
            except pika.exceptions.AMQPError as e:
                app.logger.error("queue unavailable: %s", type(e).__name__)
                weather_data = None

            if weather_data is None:
                error = "Couldn't find weather for that location. Try again."
            elif lat and lon and city:  # picked from dropdown -> show the picked label
                weather_data["display_name"] = city
            else:  # free-typed -> show what the API resolved
                weather_data["display_name"] = f'{weather_data["city"]}, {weather_data["country"]}'

    return render_template("home.html", weather=weather_data, error=error)


@app.route("/api/suggest")
def suggest():
    """return up to 10 city suggestions matching the typed prefix, biggest cities first"""
    q = request.args.get("q", "").strip().lower()
    if len(q) < 2:
        return {"results": []}
    results = []
    for c in CITIES:
        if c["name_lower"].startswith(q):
            results.append({
                "label": f'{c["name"]}, {c["country"]}' if c["country"] else c["name"],
                "lat": c["lat"],
                "lon": c["lon"],
            })
            if len(results) == 10:
                break
    return {"results": results}


@app.route("/health")
def health():
    """liveness/readiness for Kubernetes and the ALB - doesn't touch RabbitMQ"""
    return {"status": "ok"}


@app.errorhandler(404)
def handle_not_found(e):
    return render_template("not_found.html"), 404


def load_cities():
    """load ~32k world cities + ~250 countries into one list sorted by population,
    with precomputed lowercase names for fast prefix search"""
    gc = geonamescache.GeonamesCache()
    countries = gc.get_countries()
    cities_raw = gc.get_cities().values()

    capitals = {}
    for c in cities_raw:
        if c["name"] == countries.get(c["countrycode"], {}).get("capital"):
            capitals[c["countrycode"]] = (c["latitude"], c["longitude"])

    entries = []
    for c in cities_raw:
        entries.append({
            "name": c["name"],
            "name_lower": c["name"].lower(),
            "country": countries.get(c["countrycode"], {}).get("name", c["countrycode"]),
            "lat": c["latitude"],
            "lon": c["longitude"],
            "population": c["population"],
        })

    for code, country in countries.items():
        if code in capitals:
            lat, lon = capitals[code]
            entries.append({
                "name": country["name"],
                "name_lower": country["name"].lower(),
                "country": "",
                "lat": lat,
                "lon": lon,
                "population": country["population"],
            })

    entries.sort(key=lambda c: c["population"], reverse=True)
    return entries


CITIES = load_cities()

if __name__ == "__main__":
    app.run()
