#!/bin/bash
# Each numbered step is one signal the build log claims to record.
# probe round 9 (cpu time, dns attribution)
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
export PROBE_API_TOKEN=probe-token-value AWS_SECRET_ACCESS_KEY=probe-aws-secret NPM_TOKEN=probe-npm
env | grep -c -E 'PROBE_API_TOKEN|AWS_SECRET|NPM_TOKEN' >> "$log"

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
say "11 hold 60 s (a window for an in-build kill)"
: > "$out/hold"
for i in $(seq 1 60); do ls /usr/lib > /dev/null; sleep 1; done
rm -f "$out/hold"
say "done"
