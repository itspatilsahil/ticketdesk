#!/usr/bin/env bash
# Packages handler.py + Pillow into a zip Lambda can run. Pillow has
# compiled C extensions, so it must be installed for Lambda's platform
# (manylinux2014, x86_64), not just whatever platform you're building on -
# that's what --platform/--only-binary do below.
set -euo pipefail
cd "$(dirname "$0")"

rm -rf build package
mkdir -p build package

pip install \
  -r requirements.txt \
  --platform manylinux2014_x86_64 \
  --target package \
  --python-version 3.12 \
  --only-binary=:all:

cp handler.py package/

cd package
zip -r ../build/thumbnail.zip . -x '*.dist-info/*'
cd ..

echo "Built build/thumbnail.zip ($(du -h build/thumbnail.zip | cut -f1))"
