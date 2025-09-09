import os
import yaml
import json
from flask import Flask, jsonify, request
import psycopg2
from psycopg2.extras import RealDictCursor

app = Flask(__name__)

CONFIG_PATH = os.getenv("CONFIG_PATH", "/config/mappings.yml")

DB_CONFIG = {
    "user":     os.getenv("DB_USER", "postgres"),
    "host":     os.getenv("DB_HOST", "postgres-service"),
    "database": os.getenv("DB_NAME", "mydb"),
    "password": os.getenv("DB_PASSWORD", "password"),
    "port":     int(os.getenv("DB_PORT", "5432")),
}

def load_mapping():
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    mappings = data.get("mappings", [])
    # Normalize endpoints: ensure they start with / and have no trailing slash
    norm = {}
    for m in mappings:
        ep = m.get("api_endpoint", "").strip()
        if not ep.startswith("/"):
            ep = "/" + ep
        if len(ep) > 1 and ep.endswith("/"):
            ep = ep[:-1]
        norm[ep] = {
            "query": m.get("query", "").strip(),
            "columns": m.get("columns", {}) or {},
        }
    return norm

@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok"})

@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def acl_route(path: str):
    # Normalize request path
    req_path = "/" + path if not path.startswith("/") else path
    if len(req_path) > 1 and req_path.endswith("/"):
        req_path = req_path[:-1]

    mappings = load_mapping()
    if req_path not in mappings:
        return jsonify({"error": f"no mapping for endpoint '{req_path}'"}), 404

    mapping = mappings[req_path]
    query = mapping.get("query", "").strip()
    if not query:
        return jsonify({"error": "empty query in mapping"}), 500

    try:
        with psycopg2.connect(**DB_CONFIG) as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(query)
                rows = cur.fetchall()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    # Transform rows: map db columns -> api fields
    col_map = mapping.get("columns", {})  # {"db_col": "api_field"}
    out = []
    for r in rows:
        obj = {}
        for db_col, api_field in col_map.items():
            obj[api_field] = r.get(db_col)
        # If no columns specified, return the raw row dict
        if not col_map:
            obj = dict(r)
        out.append(obj)

    return jsonify(out)

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=3000)
