"""Unit tests for the Polaris sample app."""

import app as polaris_app


def test_index_returns_service_info():
    client = polaris_app.app.test_client()
    response = client.get("/")

    assert response.status_code == 200
    data = response.get_json()
    assert data["service"] == "polaris-app"
    assert data["status"] == "ok"


def test_health_endpoint():
    client = polaris_app.app.test_client()
    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json()["status"] == "healthy"
