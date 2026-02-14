#!/bin/sh
set -ex

python3 -m zipfile -e "gradle-${MINIMAL_ARG_VERSION}-bin.zip" .

mkdir -p $OUTPUT_DIR/usr/{bin,share/gradle}
cp -r "gradle-${MINIMAL_ARG_VERSION}"/* $OUTPUT_DIR/usr/share/gradle/
chmod +x $OUTPUT_DIR/usr/share/gradle/bin/gradle

# Create wrapper script that sets GRADLE_HOME
cat > $OUTPUT_DIR/usr/bin/gradle << 'EOF'
#!/bin/sh
export GRADLE_HOME=/usr/share/gradle
exec /usr/share/gradle/bin/gradle "$@"
EOF
chmod +x $OUTPUT_DIR/usr/bin/gradle
