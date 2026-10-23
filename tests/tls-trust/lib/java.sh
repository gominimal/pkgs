# lib/java.sh: the JDK on PATH (jdk-21/25/27 run in separate tasks; they
# install the same paths). See lib/Probe.java for what offline proves.

setup_java() { timeout -k 5 300 javac -d "$W/java" "$LIB/Probe.java"; }
live_java() { to java -cp "$W/java" Probe live "https://$1/" "$TIMEOUT" 2>&1 | tail -3; return 0; }
off_java()  { to java -cp "$W/java" Probe offline "$1" "$VERIFY_AT_EPOCH" 2>&1 | tail -4; return 0; }

# blocklist variant: the profile's anchors are the ONLY trust anchors, so only
# blocked.certs can refuse the chain. Live would need a JKS/PKCS12 store built
# with keytool; offline already runs the same PKIX code, so live is N/A here.
off_java_bl() { to java -cp "$W/java" Probe offline "$1" "$VERIFY_AT_EPOCH" "$W/negctl.pem" 2>&1 | tail -4; return 0; }

row java java "java -version 2>&1 | head -1" live_java off_java "path: PKIX CertPathBuilder, default trust store + blocked.certs" setup_java
row java-blocklist java "echo java, anchors trusted" - off_java_bl "blocklist: PKIX with the anchors as trust anchors; only blocked.certs can refuse" setup_java
