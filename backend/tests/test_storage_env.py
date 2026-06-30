"""Tests for storage environment variable resolution."""

import pytest

from utils import storage_env


def test_storage_bucket_prefers_storage_bucket(monkeypatch):
    monkeypatch.setenv("STORAGE_BUCKET", "primary-bucket")
    monkeypatch.setenv("S3_BUCKET_NAME", "legacy-bucket")
    assert storage_env.storage_bucket() == "primary-bucket"


def test_storage_bucket_falls_back_to_legacy_name(monkeypatch):
    monkeypatch.delenv("STORAGE_BUCKET", raising=False)
    monkeypatch.setenv("S3_BUCKET_NAME", "legacy-bucket")
    assert storage_env.storage_bucket() == "legacy-bucket"


def test_aws_region_prefers_aws_region(monkeypatch):
    monkeypatch.setenv("AWS_REGION", "ap-south-1")
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    assert storage_env.aws_region() == "ap-south-1"


def test_aws_region_falls_back_to_default_region(monkeypatch):
    monkeypatch.delenv("AWS_REGION", raising=False)
    monkeypatch.setenv("AWS_DEFAULT_REGION", "ap-south-1")
    assert storage_env.aws_region() == "ap-south-1"


def test_check_s3_storage_skipped_for_local(monkeypatch):
    monkeypatch.setenv("STORAGE_BACKEND", "local")
    status, detail = storage_env.check_s3_storage()
    assert status == "skipped"
    assert detail is None


def test_check_s3_storage_errors_when_bucket_missing(monkeypatch):
    monkeypatch.setenv("STORAGE_BACKEND", "s3")
    monkeypatch.delenv("STORAGE_BUCKET", raising=False)
    monkeypatch.delenv("S3_BUCKET_NAME", raising=False)
    status, detail = storage_env.check_s3_storage()
    assert status == "error"
    assert detail is not None
    assert "STORAGE_BUCKET" in detail
