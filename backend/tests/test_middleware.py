"""Tests for middleware: upload size limit, API key auth, CORS."""


# ---------------------------------------------------------------------------
# Upload size limit
# ---------------------------------------------------------------------------

def test_size_limit_blocks_oversized_request(client):
    """Content-Length above 604 MB must return 413."""
    resp = client.post(
        "/transcription/upload",
        content=b"x",
        headers={
            "Authorization": "Bearer ignored",
            "content-length": str(700 * 1024 * 1024),  # 700 MB
        },
    )
    assert resp.status_code == 413
    assert "413" in resp.text or "large" in resp.text.lower()


def test_size_limit_allows_small_request(client):
    """A normally-sized request must not be blocked by the size middleware."""
    # Will fail auth (no valid token), but not with 413
    resp = client.post(
        "/health",
        content=b"x" * 100,
    )
    assert resp.status_code != 413


# ---------------------------------------------------------------------------
# API key middleware
# ---------------------------------------------------------------------------

def test_api_key_not_required_by_default(client):
    """REQUIRE_API_KEY defaults to false — requests should pass through."""
    resp = client.get("/health")
    assert resp.status_code == 200


def test_api_key_blocks_when_required(client, monkeypatch):
    monkeypatch.setenv("API_KEY", "secret-key")
    monkeypatch.setenv("REQUIRE_API_KEY", "true")

    # Re-import middleware check after env change
    import utils.api_auth as api_auth
    monkeypatch.setattr(api_auth, "is_api_key_required", lambda: True)

    resp = client.get(
        "/transcription/list/all",
        headers={"Authorization": "Bearer sometoken"},
    )
    # Missing X-API-Key → 401
    assert resp.status_code == 401


def test_api_key_passes_with_correct_key(client, monkeypatch):
    monkeypatch.setenv("API_KEY", "correct-key")
    monkeypatch.setenv("REQUIRE_API_KEY", "true")

    import utils.api_auth as api_auth
    monkeypatch.setattr(api_auth, "is_api_key_required", lambda: True)

    resp = client.get(
        "/health",
        headers={"X-API-Key": "correct-key"},
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Health endpoint
# ---------------------------------------------------------------------------

def test_health_returns_ok(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert body["database"] == "ok"


def test_root_returns_message(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert "running" in resp.json()["message"].lower()
