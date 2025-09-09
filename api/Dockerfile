FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# System deps (none required for psycopg2-binary)
WORKDIR /app
COPY api/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY api/ /app/
# Default config path used by the app
ENV CONFIG_PATH=/config/mappings.yml

EXPOSE 3000
CMD ["python", "app.py"]
