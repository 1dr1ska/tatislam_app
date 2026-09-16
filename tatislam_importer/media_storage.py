"""Загрузка медиа в Yandex Object Storage (S3-совместимый).

Это тот же бакет, который использует приложение Tatislam (tatislam-media).
Ключи вида images/<uuid>.jpg, audio/<uuid>.mp3, videos/<uuid>.mp4 хранятся в
content_blocks.data.path / publications.photo_path, а приложение строит из них
публичный URL https://storage.yandexcloud.net/tatislam-media/<ключ>.
"""
from __future__ import annotations

import logging
import re
from uuid import uuid4

logger = logging.getLogger("importer")


class MediaStorage:
    def __init__(
        self,
        endpoint: str,
        region: str,
        bucket: str,
        access_key: str,
        secret_key: str,
    ) -> None:
        import boto3
        from botocore.config import Config

        self.endpoint = endpoint.rstrip("/")
        self.bucket = bucket
        self._s3 = boto3.client(
            "s3",
            endpoint_url=self.endpoint,
            region_name=region,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            config=Config(signature_version="s3v4"),
        )

    def upload(
        self,
        data: bytes,
        folder: str,
        extension: str,
        content_type: str | None = None,
    ) -> str:
        """Загружает байты как public-read объект и возвращает S3-ключ."""
        if folder not in ("images", "audio", "videos"):
            raise ValueError(f"Недопустимая папка S3: {folder!r}")
        safe_ext = extension
        if not safe_ext.startswith("."):
            safe_ext = f".{safe_ext}"
        safe_ext = re.sub(r"[^.\w]", "", safe_ext)

        key = f"{folder}/{uuid4().hex}{safe_ext}"
        kwargs = {"ACL": "public-read"}
        if content_type:
            kwargs["ContentType"] = content_type
        self._s3.put_object(Bucket=self.bucket, Key=key, Body=data, **kwargs)
        logger.info("[INFO] Uploaded to S3: %s", key)
        return key

    def public_url(self, key: str) -> str:
        return f"{self.endpoint}/{self.bucket}/{key}"