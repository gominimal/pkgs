#!/bin/bash
# Each numbered step is one signal the build log claims to record.
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

say "6 symlink + rename + setuid bit inside the prefix"
ln -s /etc/passwd "$out/passwd-link" && mv "$out/passwd-link" "$out/passwd-link2" && rm "$out/passwd-link2"
cp /bin/true "$out/suid-true" && chmod u+s "$out/suid-true" && rm "$out/suid-true"

say "7 privilege: mount, unshare, ptrace-guarded read of pid 1"
mount -t tmpfs none /mnt >> "$log" 2>&1 || say "  mount exit $?"
unshare -Ur true >> "$log" 2>&1 || say "  unshare exit $?"
cat /proc/1/environ > /dev/null 2>>"$log" || say "  /proc/1/environ exit $?"

say "8 background child outliving the script by 3 s"
( sleep 3; echo "  bg child done" >> "$log" ) &
wait
say "done"
