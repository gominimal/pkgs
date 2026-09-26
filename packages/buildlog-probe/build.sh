#!/bin/bash
# Each numbered step is one signal the build log claims to record.
# probe round 12c (sleepable getenv, fast rescan)
set -u
out=$OUTPUT_DIR/usr/share/buildlog-probe
mkdir -p "$out"
log=$out/probe.log
: > "$log"
say() { echo "$*" | tee -a "$log"; }

say "1 dns+tls: curl https://example.com"
curl -sS -m 20 -o /dev/null -w 'curl example.com http=%{http_code} ip=%{remote_ip}\n' https://example.com >> "$log" 2>&1 || say "  curl exit $?"

say "2 raw tcp connect, no dns: 1.1.1.1:443"
if exec 3<>/dev/tcp/1.1.1.1/443; then say "  tcp 1.1.1.1:443 connected"; exec 3>&-; else say "  tcp connect failed"; fi

say "3 resolver only: getent hosts example.org"
getent hosts example.org >> "$log" 2>&1 || say "  getent exit $?"

say "4 env reads: sensitive keys visible to a child exec"
export PROBE_API_TOKEN=probe-token-value AWS_SECRET_ACCESS_KEY=probe-aws-secret NPM_TOKEN=probe-npm PROBE_PLAIN_SETTING=on
env | grep -c -E 'PROBE_API_TOKEN|AWS_SECRET|NPM_TOKEN' >> "$log"

say "4b a program READS a sensitive key via libc getenv"
printf '#include <stdio.h>\n#include <stdlib.h>\nint main(void){const char*v=getenv("PROBE_API_TOKEN");printf("  getenv PROBE_API_TOKEN: %%s\\n", v?"set":"unset");return 0;}\n' > "$out/genv.c"
gcc -O1 -o "$out/token-reader" "$out/genv.c" >> "$log" 2>&1 && "$out/token-reader" | tee -a "$log"
rm -f "$out/genv.c" "$out/token-reader"

say "5 writes outside the install prefix, then deleted"
echo x > /tmp/buildlog-probe.txt && say "  wrote /tmp/buildlog-probe.txt"
echo y > "$HOME/.buildlog-probe" 2>>"$log" && say "  wrote \$HOME/.buildlog-probe"
rm -f /tmp/buildlog-probe.txt "$HOME/.buildlog-probe"

say "6 symlink + rename + setuid bit + chmod inside the prefix"
ln -s /etc/passwd "$out/passwd-link" && mv "$out/passwd-link" "$out/passwd-link2" && rm "$out/passwd-link2"
cp /bin/true "$out/suid-true" && chmod u+s "$out/suid-true" && chmod 0777 "$out/suid-true" && rm "$out/suid-true"

say "7 privilege: mount, unshare, nsenter, chroot, chown root, ptrace-guarded reads"
mount -t tmpfs none /mnt >> "$log" 2>&1 || say "  mount exit $?"
unshare -Ur true >> "$log" 2>&1 || say "  unshare -Ur exit $?"
unshare -m true >> "$log" 2>&1 || say "  unshare -m exit $?"
nsenter -t 1 -m true >> "$log" 2>&1 || say "  nsenter exit $?"
chroot / /bin/true >> "$log" 2>&1 || say "  chroot exit $?"
chown 0:0 "$log" >> "$log" 2>&1 || say "  chown root exit $?"
cat /proc/1/environ > /dev/null 2>>"$log" || say "  /proc/1/environ exit $?"
cat /proc/1/mem > /dev/null 2>>"$log" || say "  /proc/1/mem exit $?"
kill -0 1 2>>"$log" && say "  kill -0 1 ok" || say "  kill -0 1 exit $?"

say "8 bind + listen on a local port"
( exec 4<>/dev/tcp/127.0.0.1/1 ) 2>/dev/null || say "  connect 127.0.0.1:1 refused (expected)"

say "9 background child outliving the script by 3 s"
( sleep 3; echo "  bg child done" >> "$log" ) &
wait

say "10 compile storm: 48 workers x 60 preprocessor runs over the same headers"
cat > "$out/storm.c" <<'C'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#include <math.h>
#include <pthread.h>
int main(void) { return 0; }
C
t0=$(date +%s.%N)
for w in $(seq 1 48); do ( for j in $(seq 1 60); do gcc -E "$out/storm.c" -o /dev/null; done ) & done
wait
say "  storm done in $(echo "$(date +%s.%N) - $t0" | bc 2>/dev/null || echo "?") s"
rm -f "$out/storm.c"
say "12 unconnected UDP sendto 8.8.8.8:53 (a raw DNS query that bypasses the resolver)"
cat > "$out/udp.c" <<'C'
#include <arpa/inet.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
int main(void) {
  /* DNS query: id 0x1234, RD, one question "example.net" A IN */
  unsigned char q[] = {0x12,0x34,0x01,0x00,0,1,0,0,0,0,0,0,
    7,'e','x','a','m','p','l','e',3,'n','e','t',0, 0,1, 0,1};
  int s = socket(AF_INET, SOCK_DGRAM, 0);
  struct sockaddr_in to = {0};
  to.sin_family = AF_INET; to.sin_port = htons(53);
  inet_pton(AF_INET, "8.8.8.8", &to.sin_addr);
  ssize_t n = sendto(s, q, sizeof q, 0, (struct sockaddr *)&to, sizeof to);
  struct timeval tv = {2, 0};
  setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
  unsigned char r[512];
  ssize_t m = recv(s, r, sizeof r, 0);
  printf("  sendto %zd bytes, reply %zd bytes\n", n, m);
  close(s);
  return 0;
}
C
gcc -O1 -o "$out/udp" "$out/udp.c" >> "$log" 2>&1 && "$out/udp" | tee -a "$log"
rm -f "$out/udp" "$out/udp.c"

say "11 hold 5 s"
: > "$out/hold"
for i in $(seq 1 5); do ls /usr/lib > /dev/null; sleep 1; done
rm -f "$out/hold"
say "done"
