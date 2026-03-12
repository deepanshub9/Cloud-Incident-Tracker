import os
import socket
import sqlite3
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template, request

app = Flask(__name__)

DB_PATH = os.getenv("DB_PATH", os.path.join("data", "incidents.db"))
SEVERITIES = {"P1", "P2", "P3", "P4"}


def get_db_connection() -> sqlite3.Connection:
    db_dir = os.path.dirname(DB_PATH)
    if db_dir:
        os.makedirs(db_dir, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    conn = get_db_connection()
    try:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS incidents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                service TEXT NOT NULL,
                title TEXT NOT NULL,
                severity TEXT NOT NULL,
                description TEXT,
                status TEXT NOT NULL DEFAULT 'open',
                created_at TEXT NOT NULL,
                resolved_at TEXT
            )
            """
        )
        conn.commit()
    finally:
        conn.close()


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def summary() -> dict:
    conn = get_db_connection()
    try:
        rows = conn.execute(
            """
            SELECT severity, COUNT(*) as count
            FROM incidents
            WHERE status = 'open'
            GROUP BY severity
            """
        ).fetchall()
        open_count = conn.execute(
            "SELECT COUNT(*) AS count FROM incidents WHERE status = 'open'"
        ).fetchone()["count"]
        resolved_count = conn.execute(
            "SELECT COUNT(*) AS count FROM incidents WHERE status = 'resolved'"
        ).fetchone()["count"]
    finally:
        conn.close()

    by_severity = {"P1": 0, "P2": 0, "P3": 0, "P4": 0}
    for row in rows:
        by_severity[row["severity"]] = row["count"]

    return {
        "open": open_count,
        "resolved": resolved_count,
        "severity": by_severity,
    }


init_db()


@app.get("/")
def home():
    return render_template(
        "index.html",
        app_name=os.getenv("APP_NAME", "Cloud Incident Tracker"),
        env_name=os.getenv("ENV_NAME", "local"),
        version=os.getenv("APP_VERSION", "v1"),
        hostname=socket.gethostname(),
        utc_now=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
        initial_summary=summary(),
    )


@app.get("/health")
def health():
    return jsonify(status="ok"), 200


@app.get("/api/info")
def info():
    return jsonify(
        app=os.getenv("APP_NAME", "Cloud Incident Tracker"),
        env=os.getenv("ENV_NAME", "local"),
        version=os.getenv("APP_VERSION", "v1"),
        hostname=socket.gethostname(),
        time_utc=datetime.now(timezone.utc).isoformat(),
    )


@app.get("/api/summary")
def get_summary():
    return jsonify(summary())


@app.get("/api/incidents")
def list_incidents():
    status = request.args.get("status", "open")
    if status not in {"open", "resolved", "all"}:
        return jsonify(error="status must be open, resolved, or all"), 400

    conn = get_db_connection()
    try:
        if status == "all":
            rows = conn.execute(
                "SELECT * FROM incidents ORDER BY id DESC"
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM incidents WHERE status = ? ORDER BY id DESC", (status,)
            ).fetchall()
    finally:
        conn.close()

    return jsonify([dict(r) for r in rows])


@app.post("/api/incidents")
def create_incident():
    payload = request.get_json(silent=True) or {}
    service = str(payload.get("service", "")).strip()
    title = str(payload.get("title", "")).strip()
    severity = str(payload.get("severity", "")).strip().upper()
    description = str(payload.get("description", "")).strip()

    if not service or not title:
        return jsonify(error="service and title are required"), 400
    if severity not in SEVERITIES:
        return jsonify(error="severity must be one of P1, P2, P3, P4"), 400

    created_at = now_utc_iso()

    conn = get_db_connection()
    try:
        cur = conn.execute(
            """
            INSERT INTO incidents (service, title, severity, description, status, created_at)
            VALUES (?, ?, ?, ?, 'open', ?)
            """,
            (service, title, severity, description, created_at),
        )
        conn.commit()
        incident_id = cur.lastrowid
        row = conn.execute("SELECT * FROM incidents WHERE id = ?", (incident_id,)).fetchone()
    finally:
        conn.close()

    return jsonify(dict(row)), 201


@app.patch("/api/incidents/<int:incident_id>/resolve")
def resolve_incident(incident_id: int):
    resolved_at = now_utc_iso()
    conn = get_db_connection()
    try:
        cur = conn.execute(
            """
            UPDATE incidents
            SET status = 'resolved', resolved_at = ?
            WHERE id = ? AND status = 'open'
            """,
            (resolved_at, incident_id),
        )
        conn.commit()
        if cur.rowcount == 0:
            return jsonify(error="incident not found or already resolved"), 404

        row = conn.execute("SELECT * FROM incidents WHERE id = ?", (incident_id,)).fetchone()
    finally:
        conn.close()

    return jsonify(dict(row))


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port, debug=False)
