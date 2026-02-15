#!/bin/sh
set -ex

SITE_DIR=$OUTPUT_DIR/usr/lib/python3.13/site-packages
mkdir -p "$SITE_DIR"
python3 -m zipfile -e pip-26.0.1-py3-none-any.whl "$SITE_DIR"

# Replace the bundled pip wheel in ensurepip so venvs get the new version
ENSUREPIP_DIR=$OUTPUT_DIR/usr/lib/python3.13/ensurepip/_bundled
mkdir -p "$ENSUREPIP_DIR"
cp pip-26.0.1-py3-none-any.whl "$ENSUREPIP_DIR/"

# Update ensurepip's version reference
INIT_DIR=$OUTPUT_DIR/usr/lib/python3.13/ensurepip
cp /usr/lib/python3.13/ensurepip/__init__.py "$INIT_DIR/__init__.py"
sed -i 's/_PIP_VERSION = "25.2"/_PIP_VERSION = "26.0.1"/' "$INIT_DIR/__init__.py"
