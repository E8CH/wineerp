"""Cloudflare R2(S3 호환) StoragePort 어댑터 — boto3. 자격은 env(R2_*).

실제 업로드는 R2 계정 자격이 필요(범위 밖 검증). 로컬은 storage_local로 폴백.
"""
from __future__ import annotations

import boto3


class R2StorageAdapter:
    def __init__(
        self, *, account_id: str, access_key_id: str, secret_access_key: str, bucket: str
    ) -> None:
        self._bucket = bucket
        self._client = boto3.client(
            "s3",
            endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
            aws_access_key_id=access_key_id,
            aws_secret_access_key=secret_access_key,
            region_name="auto",
        )

    def put_object(self, data: bytes, key: str, content_type: str) -> str:
        self._client.put_object(
            Bucket=self._bucket, Key=key, Body=data, ContentType=content_type
        )
        return f"r2:///{self._bucket}/{key}"

    def get_object(self, key: str) -> bytes:
        try:
            resp = self._client.get_object(Bucket=self._bucket, Key=key)
        except self._client.exceptions.NoSuchKey as exc:
            raise FileNotFoundError(key) from exc
        return resp["Body"].read()
