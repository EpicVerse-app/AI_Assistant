"""Shared input validation helpers."""

from __future__ import annotations

import re

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def normalize_email(value: str) -> str:
    return value.strip().lower()


def validate_email(value: str) -> str:
    email = normalize_email(value)
    if not _EMAIL_RE.match(email):
        raise ValueError("Invalid email address.")
    return email


def validate_password_register(value: str) -> str:
    if len(value) < 8:
        raise ValueError("Password must be at least 8 characters.")
    if len(value) > 128:
        raise ValueError("Password must be at most 128 characters.")
    return value


def validate_password_login(value: str) -> str:
    if not value:
        raise ValueError("Password is required.")
    if len(value) > 128:
        raise ValueError("Password is too long.")
    return value


def validate_full_name(value: str) -> str:
    name = value.strip()
    if not name:
        raise ValueError("Full name is required.")
    if len(name) > 255:
        raise ValueError("Full name is too long.")
    return name
