"""
Milestone 5 thumbnail generator.

Triggered by S3 ObjectCreated events under the "uploads/" prefix of the
attachments bucket. Downloads the image, resizes it, and writes the result
back under "thumbnails/" - the same path, different top-level prefix (the
API's AttachmentController mirrors this same substitution when it builds
presigned GET URLs, so neither side needs a database to agree on the
mapping).

Kept deliberately small: one file, one dependency (Pillow), no framework.
"""
import io
import logging
import os

import boto3
from PIL import Image

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")

UPLOAD_PREFIX = "uploads/"
THUMBNAIL_PREFIX = "thumbnails/"
THUMBNAIL_SIZE = (200, 200)


def handler(event, context):
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = _url_decode(record["s3"]["object"]["key"])

        if not key.startswith(UPLOAD_PREFIX):
            logger.info("Ignoring object outside the uploads/ prefix: %s", key)
            continue

        logger.info("Thumbnailing s3://%s/%s", bucket, key)

        obj = s3.get_object(Bucket=bucket, Key=key)
        content_type = obj.get("ContentType", "")

        if not content_type.startswith("image/"):
            logger.info("Skipping non-image attachment: %s (%s)", key, content_type)
            continue

        image = Image.open(io.BytesIO(obj["Body"].read()))
        image.thumbnail(THUMBNAIL_SIZE)

        buffer = io.BytesIO()
        fmt = (image.format or "PNG")
        image.convert("RGB" if fmt.upper() in ("JPEG", "JPG") else image.mode).save(buffer, format=fmt)
        buffer.seek(0)

        thumbnail_key = THUMBNAIL_PREFIX + key[len(UPLOAD_PREFIX):]
        s3.put_object(
            Bucket=bucket,
            Key=thumbnail_key,
            Body=buffer,
            ContentType=content_type,
        )
        logger.info("Wrote thumbnail to s3://%s/%s", bucket, thumbnail_key)

    return {"statusCode": 200}


def _url_decode(key: str) -> str:
    # S3 event keys arrive URL-encoded (spaces as '+', etc.)
    from urllib.parse import unquote_plus
    return unquote_plus(key)
