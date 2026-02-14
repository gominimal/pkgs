#!/bin/sh
set -ex

tar xf "apache-maven-${MINIMAL_ARG_VERSION}-bin.tar.gz"

mkdir -p $OUTPUT_DIR/usr/{bin,share/maven}
cp -r "apache-maven-${MINIMAL_ARG_VERSION}"/* $OUTPUT_DIR/usr/share/maven/

# Create wrapper script that sets M2_HOME
cat > $OUTPUT_DIR/usr/bin/mvn << 'EOF'
#!/bin/sh
export M2_HOME=/usr/share/maven
exec /usr/share/maven/bin/mvn "$@"
EOF
chmod +x $OUTPUT_DIR/usr/bin/mvn
