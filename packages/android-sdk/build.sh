#!/bin/sh
set -ex

# Extract command-line tools
python3 -m zipfile -e "commandlinetools-linux-${MINIMAL_ARG_VERSION}_latest.zip" cmdline-extract

SDK_ROOT="$OUTPUT_DIR/usr/lib/android-sdk"
mkdir -p "$SDK_ROOT/cmdline-tools/latest"

# Move tools into the expected directory structure
cp -r cmdline-extract/cmdline-tools/* "$SDK_ROOT/cmdline-tools/latest/"
# 22.0 also ships `bin/android`, Google's new native CLI: a prebuilt x86-64
# ELF (no arm64 build), not needed by the Java tools we wrap. Drop it so the
# package stays the same Java toolset on both arches, and so no native binary
# sits in the `sdk` data output.
rm -f "$SDK_ROOT/cmdline-tools/latest/bin/android"
chmod +x "$SDK_ROOT/cmdline-tools/latest/bin/"*

# Pre-accept licenses
mkdir -p "$SDK_ROOT/licenses"
echo -e "\n24333f8a63b6825ea9c5514f83c2829b004d1fee" > "$SDK_ROOT/licenses/android-sdk-license"
echo -e "\n84831b9409646a918e30573bab4c9c91346d8abd" > "$SDK_ROOT/licenses/android-sdk-preview-license"

# Create wrapper script for sdkmanager
mkdir -p "$OUTPUT_DIR/usr/bin"

SDK_LIB="/usr/lib/android-sdk/cmdline-tools/latest/lib"
cat > "$OUTPUT_DIR/usr/bin/sdkmanager" << EOF
#!/bin/sh
ANDROID_HOME="\${ANDROID_HOME:-/usr/lib/android-sdk}"
exec java -Dcom.android.sdklib.toolsdir=$SDK_LIB/.. -classpath "$SDK_LIB/sdkmanager-classpath.jar" com.android.sdklib.tool.sdkmanager.SdkManagerCli --sdk_root="\$ANDROID_HOME" "\$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/sdkmanager"
