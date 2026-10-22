# lib/controls.sh: the two rows that prove the harness itself works. Both use
# curl (live) / openssl verify (offline) against stores built from the box's
# system bundle at start-up (see build_control_stores in run.sh):
#   $W/selftest.pem = system bundle MINUS the profile's chains/anchors.pem
#   $W/negctl.pem   = selftest.pem PLUS chains/anchors.pem
#
# SELFTEST must read FIXED: a store without the anchors rejects every bad
#   target and still accepts every positive. If not, the classifier or the
#   profile is broken, not the packages.
# NEGCONTROL must read VULNERABLE on EVERY bad target: a client told to trust
#   the anchors connects/accepts. This proves each target is still a working
#   probe (host up, chain still anchored at the profile's roots, not expired at
#   the pinned instant). If any bad target fails here, a FIXED elsewhere for
#   that target means nothing.

live_ctl() { # $1=bundle $2=host
  local o rc; o=$(to curl -sS -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" --cacert "$1" --capath "$W/emptydir" "https://$2/" 2>&1); rc=$?
  echo "rc=$rc $o"; [ $rc -eq 0 ] && echo "@@CONNECTED@@"
  [ $rc -eq 60 ] && echo "SSL certificate problem (curl exit 60)"; return 0
}
off_ctl() { ossl_verify_verdict "$(ossl_verify_with "$1" - "$2")"; }

live_selftest() { live_ctl "$W/selftest.pem" "$1"; }
off_selftest()  { off_ctl "$W/selftest.pem" "$1"; }
live_negctl()   { live_ctl "$W/negctl.pem" "$1"; }
off_negctl()    { off_ctl "$W/negctl.pem" "$1"; }

row SELFTEST   curl "echo store minus anchors"   live_selftest off_selftest "control: openssl verify, system bundle minus the profile anchors"
row NEGCONTROL curl "echo store plus anchors"    live_negctl   off_negctl   "control: openssl verify, system bundle plus the profile anchors"
