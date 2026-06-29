"""Tests for /auth endpoints: register, login, /me."""

import pytest
from tests.conftest import auth_headers, register_and_login


# ---------------------------------------------------------------------------
# Register
# ---------------------------------------------------------------------------

def test_register_success(client):
    resp = client.post("/auth/register", json={
        "email": "alice@example.com",
        "password": "strongpass1",
        "full_name": "Alice",
    })
    assert resp.status_code == 201
    body = resp.json()
    assert "access_token" in body
    assert body["user"]["email"] == "alice@example.com"
    assert body["token_type"] == "bearer"


def test_register_duplicate_email(client):
    payload = {"email": "bob@example.com", "password": "pass1234", "full_name": "Bob"}
    client.post("/auth/register", json=payload)
    resp = client.post("/auth/register", json=payload)
    assert resp.status_code == 409


def test_register_invalid_email(client):
    resp = client.post("/auth/register", json={
        "email": "not-an-email",
        "password": "pass1234",
        "full_name": "Bad Email",
    })
    assert resp.status_code == 422


def test_register_short_password(client):
    resp = client.post("/auth/register", json={
        "email": "carol@example.com",
        "password": "short",
        "full_name": "Carol",
    })
    assert resp.status_code == 422


def test_register_missing_fields(client):
    resp = client.post("/auth/register", json={"email": "dave@example.com"})
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------

def test_login_success(client):
    client.post("/auth/register", json={
        "email": "eve@example.com", "password": "mypassword1", "full_name": "Eve",
    })
    resp = client.post("/auth/login", json={
        "email": "eve@example.com", "password": "mypassword1",
    })
    assert resp.status_code == 200
    assert "access_token" in resp.json()


def test_login_wrong_password(client):
    client.post("/auth/register", json={
        "email": "frank@example.com", "password": "correct-pass", "full_name": "Frank",
    })
    resp = client.post("/auth/login", json={
        "email": "frank@example.com", "password": "wrong-pass",
    })
    assert resp.status_code == 401


def test_login_unknown_email(client):
    resp = client.post("/auth/login", json={
        "email": "ghost@example.com", "password": "doesntmatter",
    })
    assert resp.status_code == 401


def test_login_email_case_insensitive(client):
    client.post("/auth/register", json={
        "email": "Grace@Example.com", "password": "pass1234", "full_name": "Grace",
    })
    resp = client.post("/auth/login", json={
        "email": "grace@example.com", "password": "pass1234",
    })
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# /auth/me
# ---------------------------------------------------------------------------

def test_me_returns_user(client):
    token = register_and_login(client, email="henry@example.com")
    resp = client.get("/auth/me", headers=auth_headers(token))
    assert resp.status_code == 200
    assert resp.json()["email"] == "henry@example.com"


def test_me_without_token(client):
    resp = client.get("/auth/me")
    assert resp.status_code == 401


def test_me_with_bad_token(client):
    resp = client.get("/auth/me", headers={"Authorization": "Bearer garbage.token.here"})
    assert resp.status_code == 401
