from flask import Flask, jsonify, request, render_template_string
import docker

app = Flask(__name__)

PAGE = """
<h2>Running containers</h2>
<p> IP: {{ client_ip }}</p>
<table border="1" cellpadding="5">
  <tr><th>Name</th><th>ID</th><th>Image</th><th>Status</th></tr>
  {% for c in containers %}
  <tr><td>{{ c.name }}</td><td>{{ c.id }}</td><td>{{ c.image }}</td><td>{{ c.status }}</td></tr>
  {% endfor %}
</table>
"""

def get_containers():
    client = docker.from_env() # connects via /var/run/docker.sock which read env var DOCKER_HOST 
    return [
        {
            "name": c.name,
            "id": c.short_id,
            "image": c.attrs["Config"]["Image"],
            "status": c.status,
        }
        for c in client.containers.list() 
    ]

@app.route("/")
#return the main HTML page with the list of running containers and the client's IP address
def index():
    client_ip = request.headers.get("X-Real-IP", request.remote_addr)
    return render_template_string(PAGE, containers=get_containers(), client_ip=client_ip)

@app.route("/api/containers")
#return a JSON response with the list of running containers
def api_containers():
    return jsonify(get_containers())

@app.route("/health")
#return a JSON response indicating the health status of the application {"status": "ok"} with a 200 HTTP status code
def health():
    return jsonify(status="ok")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)