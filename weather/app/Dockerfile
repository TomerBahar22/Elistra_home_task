# One image, two roles:
#   web    -> default CMD (gunicorn)
#   worker -> Kubernetes overrides the command: ["python", "worker.py"]
FROM python:3.14-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --create-home weatheruser
USER weatheruser
EXPOSE 8080
# Threads: each web request waits for a worker's reply, so one process must
# hold many requests in flight at once (otherwise the queue never fills up).
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--threads", "16", "--timeout", "60", "app:app"]
