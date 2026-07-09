"""Polaris sample application for the GitOps lab."""

import os

from flask import Flask, jsonify

app = Flask(__name__)
VERSION = os.environ.get("APP_VERSION", "dev")


@app.route("/")
def index():
    return jsonify(
        {
            "service": "polaris-app",
            "version": VERSION,
            "status": "ok",
            "message": "Hello from Polaris GitOps lab!",
        }
    )


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
