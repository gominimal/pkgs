#!/bin/sh
set -ex

# Extract command-line tools
python3 -m zipfile -e "commandlinetools-linux-${MINIMAL_ARG_VERSION}_latest.zip" cmdline-extract

SDK_ROOT="$OUTPUT_DIR/usr/lib/android-sdk"
mkdir -p "$SDK_ROOT/cmdline-tools/latest"

# Move tools into the expected directory structure
cp -r cmdline-extract/cmdline-tools/* "$SDK_ROOT/cmdline-tools/latest/"

# Pre-accept licenses
mkdir -p "$SDK_ROOT/licenses"
echo -e "\n24333f8a63b6825ea9c5514f83c2829b004d1fee" > "$SDK_ROOT/licenses/android-sdk-license"
echo -e "\n84831b9409646a918e30573bab4c9c91346d8abd" > "$SDK_ROOT/licenses/android-sdk-preview-license"

# Create wrapper script for sdkmanager
mkdir -p "$OUTPUT_DIR/usr/bin"

cat > "$OUTPUT_DIR/usr/bin/sdkmanager" << 'EOF'
#!/bin/sh
export ANDROID_HOME="${ANDROID_HOME:-/usr/lib/android-sdk}"
exec /usr/lib/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root="$ANDROID_HOME" "$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/sdkmanager"
