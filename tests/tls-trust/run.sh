#!/usr/bin/env bash
# tests/tls-trust/run.sh: does every TLS client we ship refuse a distrusted CA?
#
#   run.sh --mode live|offline --profile <dir> [--only REGEX] [--rows REGEX]
#          [--json out.json|-] [--jobs N] [--timeout S] [--details fail|all|none]
#
# Runs INSIDE a min box (see minimal.toml and README.md), so every client and
# every trust store is the one our packages ship, never the host's.
#
#   live     one TLS handshake per client x host in the profile's targets.txt
#            (must be refused) and positives.txt (must connect). Only a
#            certificate-verification error counts as a refusal; DNS, connect
#            and timeout errors are NET-ERR and make the row INCONCLUSIVE.
#   offline  no network: each runtime's own verifier (or, where it has none,
#            the files it loads) validates the profile's captured chains at the
#            profile's pinned instant. Rows that cannot be checked honestly
#            without a handshake read "N/A (live-only)". lib/<family>.sh says
#            per row what offline proves; the table legend repeats it.
#
# Every run also carries two control rows (lib/controls.sh): SELFTEST must
# read FIXED and NEGCONTROL must read VULNERABLE, or the run is invalid.
# Rows named *-blocklist run with the profile's anchors TRUSTED, so only the
# client's own distrusted-cert/SPKI list can refuse; a profile opts in per row
# with "blocklist_rows = ..." in expected.txt.
#
# Verdicts:  VULNERABLE    a bad target connected / was accepted
#            FIXED         every bad target refused AND every positive accepted
#            INCONCLUSIVE  anything else (positive failed, NET-ERR, ERR, missing)
# Exit: 0 clean | 1 INCONCLUSIVE rows | 2 VULNERABLE rows | 3 harness invalid
#
# Contacts only the hosts listed in the profile (live mode). Writes only under
# a mktemp dir that is removed on exit. Needs no secrets and no private keys.
set -u
export LC_ALL=C

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB=$HERE/lib
MODE="" PROFILE="" ONLY="" ROWS="" JSON="" JOBS=8 TIMEOUT=15 DETAILS=fail

die() { echo "run.sh: $*" >&2; exit 3; }
while [ $# -gt 0 ]; do
  case $1 in
    --mode|--profile|--only|--rows|--json|--jobs|--timeout|--details)
      [ $# -ge 2 ] || die "$1 needs a value" ;;
  esac
  case $1 in
    --mode) MODE=${2:-}; shift 2 ;;
    --profile) PROFILE=${2:-}; shift 2 ;;
    --only) ONLY=${2:-}; shift 2 ;;
    --rows) ROWS=${2:-}; shift 2 ;;
    --json) JSON=${2:-}; shift 2 ;;
    --jobs) JOBS=${2:-}; shift 2 ;;
    --timeout) TIMEOUT=${2:-}; shift 2 ;;
    --details) DETAILS=${2:-}; shift 2 ;;
    -h|--help) sed -n '2,/^set -u/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done
case $MODE in live|offline) ;; *) die "--mode must be live or offline" ;; esac
case $JOBS in ''|*[!0-9]*|0) die "--jobs must be a positive integer" ;; esac
case $TIMEOUT in ''|*[!0-9]*|0) die "--timeout must be a positive integer (seconds)" ;; esac
case $DETAILS in fail|all|none) ;; *) die "--details must be fail, all or none" ;; esac
JOBS=$((10#$JOBS)) TIMEOUT=$((10#$TIMEOUT))   # "08" is not octal here
[ -n "$PROFILE" ] || die "--profile is required"
[ -d "$PROFILE" ] || PROFILE=$HERE/$PROFILE
[ -d "$PROFILE" ] || die "no such profile: $PROFILE"
PROFILE=$(cd "$PROFILE" && pwd)
START_MS=$(date +%s%3N)

# ---------------------------------------------------------------- profile
# targets.txt: "<host> <group> <label>"; positives.txt: "<host>"; '#' comments.
# expected.txt: "verify_at = <ISO-8601 UTC>" plus prose.
T_HOST=() T_GROUP=() P_HOST=() GROUPS_SEEN=()
ok_host() { [[ $1 =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] || die "refusing odd host name: $1"; }
while read -r h g _; do
  [ -z "$h" ] || [ "${h#\#}" != "$h" ] && continue
  ok_host "$h"; T_HOST+=("$h"); T_GROUP+=("${g:-bad}")
  [[ " ${GROUPS_SEEN[*]-} " == *" ${g:-bad} "* ]] || GROUPS_SEEN+=("${g:-bad}")
done < "$PROFILE/targets.txt"
while read -r h _; do
  [ -z "$h" ] || [ "${h#\#}" != "$h" ] && continue
  ok_host "$h"; P_HOST+=("$h")
done < "$PROFILE/positives.txt"
[ ${#T_HOST[@]} -gt 0 ] && [ ${#P_HOST[@]} -gt 0 ] || die "profile needs targets and positives"
VERIFY_AT_ISO=$(sed -n 's/^verify_at *= *//p' "$PROFILE/expected.txt" | head -1)
VERIFY_AT_EPOCH=$(date -u -d "$VERIFY_AT_ISO" +%s 2>/dev/null) || die "expected.txt: bad verify_at '$VERIFY_AT_ISO'"
BLOCKLIST_ROWS=$(sed -n 's/^blocklist_rows *= *//p' "$PROFILE/expected.txt" | head -1)
ALL_HOST=("${T_HOST[@]}" "${P_HOST[@]}"); NB=${#T_HOST[@]}; NT=${#ALL_HOST[@]}
target_arg() { # index -> host (live) or chain file (offline)
  if [ "$MODE" = live ]; then echo "${ALL_HOST[$1]}"
  elif [ "$1" -lt "$NB" ]; then echo "$PROFILE/chains/bad/${ALL_HOST[$1]}.pem"
  else echo "$PROFILE/chains/good/${ALL_HOST[$1]}.pem"; fi
}
if [ "$MODE" = offline ]; then
  for ((j = 0; j < NT; j++)); do [ -s "$(target_arg $j)" ] || die "missing chain $(target_arg $j)"; done
fi

# Leaf expiry of the captured BAD chains. Offline verifies at verify_at, so it
# never goes stale, but live mode handshakes with the real targets, and the day
# their leaves expire NEGCONTROL reads BROKEN and every run exits 3. Warn early
# enough to re-capture (README "Maintenance"); EXPIRY_WARN_DAYS overrides 60.
EXPIRY_WARN_DAYS=${EXPIRY_WARN_DAYS:-60}
EARLIEST_EXPIRY="" EARLIEST_EXPIRY_HOST=""
for ((j = 0; j < NB; j++)); do
  f=$PROFILE/chains/bad/${T_HOST[$j]}.pem
  [ -s "$f" ] || continue
  e=$(openssl x509 -in "$f" -noout -enddate 2>/dev/null | sed 's/^notAfter=//')
  e=$(date -u -d "$e" +%s 2>/dev/null) || continue
  if [ -z "$EARLIEST_EXPIRY" ] || [ "$e" -lt "$EARLIEST_EXPIRY" ]; then EARLIEST_EXPIRY=$e EARLIEST_EXPIRY_HOST=${T_HOST[$j]}; fi
done
EXPIRY_NOTE=""
if [ -n "$EARLIEST_EXPIRY" ]; then
  days=$(( (EARLIEST_EXPIRY - $(date -u +%s)) / 86400 ))
  when=$(date -u -d "@$EARLIEST_EXPIRY" +%Y-%m-%d)
  if [ "$days" -lt 0 ]; then
    EXPIRY_NOTE="WARNING: target leaf $EARLIEST_EXPIRY_HOST expired on $when; live NEGCONTROL will read BROKEN until chains/ is re-captured"
  elif [ "$days" -le "$EXPIRY_WARN_DAYS" ]; then
    EXPIRY_NOTE="WARNING: target leaf $EARLIEST_EXPIRY_HOST expires on $when ($days days); re-capture chains/ before then (README: Maintenance)"
  fi
fi

# ---------------------------------------------------------------- sandbox
W=$(mktemp -d "${TMPDIR:-/tmp}/tls-trust.XXXXXX") || die "mktemp failed"
trap 'rm -rf "$W"' EXIT
export HOME=$W/home XDG_CACHE_HOME=$W/cache XDG_CONFIG_HOME=$W/config
mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$W/raw" "$W/res" "$W/ver" "$W/emptydir"
export W LIB TIMEOUT VERIFY_AT_EPOCH VERIFY_AT_ISO

# ---------------------------------------------------------------- rows
# row NAME BINARY VERSION_CMD LIVE_FN OFFLINE_FN PROOF [SETUP_FN]
# OFFLINE_FN "-" = no honest offline check; PROOF then says why.
R_NAME=() R_BIN=() R_VER=() R_LIVE=() R_OFF=() R_PROOF=() R_SETUP=()
row() {
  R_NAME+=("$1"); R_BIN+=("$2"); R_VER+=("$3"); R_LIVE+=("$4"); R_OFF+=("$5"); R_PROOF+=("$6"); R_SETUP+=("${7:-}")
}
# shellcheck source=/dev/null
for f in common c-clients python httpie js java go rust controls; do . "$LIB/$f.sh"; done

SEL=()
for ((i = 0; i < ${#R_NAME[@]}; i++)); do
  n=${R_NAME[$i]}
  case $n in SELFTEST|NEGCONTROL) SEL+=("$i"); continue ;; esac
  # *-blocklist rows trust the anchors on purpose, so they only mean something
  # for clients the incident says ship their own blocklist (expected.txt).
  case $n in *-blocklist) [[ " $BLOCKLIST_ROWS " == *" $n "* ]] || continue ;; esac
  if [ -n "$ROWS" ] && ! grep -Eq -- "$ROWS" <<<"$n"; then continue; fi
  if [ -n "$ONLY" ] && ! grep -Eq -- "$ONLY" <<<"$n"; then continue; fi
  SEL+=("$i")
done

# A filter that selects no client must not pass on the controls alone.
[ ${#SEL[@]} -gt 2 ] || die "no client rows match --rows '${ROWS}' / --only '${ONLY}'"

# ---------------------------------------------------------------- stores
# The system bundle is the first that exists of the usual paths (what the
# probes' clients load); the controls derive from it.
BUNDLE=""
for f in ${SSL_CERT_FILE:-} /etc/ssl/certs/ca-certificates.crt /etc/ssl/cert.pem /etc/pki/tls/certs/ca-bundle.crt; do
  [ -f "$f" ] && { BUNDLE=$f; break; }
done
ANCHOR_FPS=() ANCHOR_NAMES=() BUNDLE_N=0 ANCHORS_IN_BUNDLE=()
split_pem() { awk -v d="$2" '/BEGIN CERTIFICATE/{n++; f=sprintf("%s/%04d.pem",d,n)} f{print > f} /END CERTIFICATE/{close(f); f=""}' "$1"; }
fp() { openssl x509 -in "$1" -noout -fingerprint -sha256 | sed 's/.*=//; s/://g' | tr 'A-F' 'a-f'; }
build_control_stores() {
  local c f
  mkdir -p "$W/anchors" "$W/split"; : > "$W/selftest.pem"
  split_pem "$PROFILE/chains/anchors.pem" "$W/anchors"
  for c in "$W"/anchors/*.pem; do
    ANCHOR_FPS+=("$(fp "$c")"); ANCHOR_NAMES+=("$(openssl x509 -in "$c" -noout -subject | sed 's/.*CN *= *//')")
  done
  [ -n "$BUNDLE" ] || return 1
  split_pem "$BUNDLE" "$W/split"
  for c in "$W"/split/*.pem; do
    BUNDLE_N=$((BUNDLE_N + 1)); f=$(fp "$c")
    if [[ " ${ANCHOR_FPS[*]} " == *" $f "* ]]; then ANCHORS_IN_BUNDLE+=("$f"); else cat "$c" >> "$W/selftest.pem"; fi
  done
  cat "$W/selftest.pem" "$PROFILE/chains/anchors.pem" > "$W/negctl.pem"
  [ -s "$W/selftest.pem" ]
}
build_control_stores || echo "WARNING: no system bundle found; SELFTEST/NEGCONTROL cannot run"

# ---------------------------------------------------------------- header
PIN=$(sed -n 's/^locked_commit *= *"\(.*\)"/\1/p' "$HERE/minimal.toml" 2>/dev/null | head -1)
echo "=== tls-trust: profile $(basename "$PROFILE"), mode $MODE ==="
echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)   host: $(uname -srm)   pkgs pin: ${PIN:-unknown}   jobs: $JOBS   timeout: ${TIMEOUT}s"
[ "$MODE" = offline ] && echo "offline verification instant (expected.txt verify_at): $VERIFY_AT_ISO"
[ -n "$EARLIEST_EXPIRY" ] && echo "earliest target leaf expiry: $(date -u -d "@$EARLIEST_EXPIRY" +%Y-%m-%d) ($EARLIEST_EXPIRY_HOST)"
[ -n "$EXPIRY_NOTE" ] && echo "$EXPIRY_NOTE"
echo "system bundle: ${BUNDLE:-NOT FOUND} ($BUNDLE_N certs); openssl $(openssl version -d 2>/dev/null)"
for ((k = 0; k < ${#ANCHOR_FPS[@]}; k++)); do
  if [[ " ${ANCHORS_IN_BUNDLE[*]-} " == *" ${ANCHOR_FPS[$k]} "* ]]; then s=YES; else s=no; fi
  echo "  bundle contains profile anchor '${ANCHOR_NAMES[$k]}': $s"
done
env | grep -iE '^(https?_proxy|all_proxy|no_proxy|ssl_cert_file|ssl_cert_dir|node_extra_ca_certs|node_options|requests_ca_bundle|curl_ca_bundle|deno_tls_ca_store|uv_system_certs|pip_cert)=' | sed -E 's#(://)[^/@]*@#\1***@#; s/^/env: /'

# ---------------------------------------------------------------- run
RUNNING=0
spawn() { # run "$@" in the background, at most $JOBS at a time
  "$@" &
  RUNNING=$((RUNNING + 1))
  if [ "$RUNNING" -ge "$JOBS" ]; then wait -n; RUNNING=$((RUNNING - 1)); fi
}
probe_job() { # row-index target-index fn
  local raw=$W/raw/$1.$2 s
  "$3" "$(target_arg "$2")" > "$raw" 2>&1
  s=$(classify "$MODE" "$raw")
  # A live network error or crash says nothing about trust. Retry it once so
  # a transient blip doesn't turn a weekly run INCONCLUSIVE. A trust verdict is
  # never retried.
  if [ "$MODE" = live ] && { [ "$s" = NET-ERR ] || [ "$s" = ERR ]; }; then
    { echo "--- first attempt: $s; retrying once"; "$3" "$(target_arg "$2")"; } >> "$raw" 2>&1
    s=$(sed -n '/^--- first attempt/,$p' "$raw" > "$raw.2"; classify "$MODE" "$raw.2")
  fi
  echo "$s" > "$W/res/$1.$2"
}
version_job() { eval "${R_VER[$1]}" 2>&1 | head -1 | tr -s ' ' | cut -c1-28 > "$W/ver/$1"; }

# Per-row state: run | missing | na | setup-failed
declare -A STATE
for i in "${SEL[@]}"; do
  if ! have "${R_BIN[$i]}"; then STATE[$i]=missing
  elif [ "$MODE" = offline ] && [ "${R_OFF[$i]}" = - ]; then STATE[$i]=na
  elif [ "$MODE" = live ] && [ "${R_LIVE[$i]}" = - ]; then STATE[$i]=na
  elif [ "${R_NAME[$i]}" = SELFTEST ] || [ "${R_NAME[$i]}" = NEGCONTROL ]; then
    [ -s "$W/negctl.pem" ] && STATE[$i]=run || STATE[$i]=setup-failed
  elif [ "${R_NAME[$i]}" = node-sysca ] && ! node --use-system-ca -e 0 >/dev/null 2>&1; then STATE[$i]=missing
  else STATE[$i]=run; fi
done
# One-time compiles (java, go) run in parallel, each distinct setup function
# ONCE even when several rows share it (go + go-blocklist build into the same
# dir). Their logs go to the details.
declare -A SETUP_STARTED
for i in "${SEL[@]}"; do
  fn=${R_SETUP[$i]}
  [ "${STATE[$i]}" = run ] && [ -n "$fn" ] && [ -z "${SETUP_STARTED[$fn]:-}" ] || continue
  SETUP_STARTED[$fn]=1
  { "$fn" > "$W/setup.$fn.log" 2>&1; echo $? > "$W/setup.$fn.rc"; } &
done
wait
for i in "${SEL[@]}"; do
  fn=${R_SETUP[$i]}
  [ -n "$fn" ] && [ -f "$W/setup.$fn.rc" ] && [ "$(cat "$W/setup.$fn.rc")" != 0 ] && STATE[$i]=setup-failed
done
for i in "${SEL[@]}"; do
  [ "${STATE[$i]}" = missing ] || spawn version_job "$i"
  [ "${STATE[$i]}" = run ] || continue
  if [ "$MODE" = live ]; then fn=${R_LIVE[$i]}; else fn=${R_OFF[$i]}; fi
  for ((j = 0; j < NT; j++)); do spawn probe_job "$i" "$j" "$fn"; done
  echo "  probing ${R_NAME[$i]} ($NT targets)"   # progress; also keeps the task's output stream alive
done
wait

# ---------------------------------------------------------------- verdicts
if [ "$MODE" = live ]; then OKV=CONNECTED; NOV=CERT-FAIL; LET="F C"; else OKV=ACCEPTED; NOV=REJECTED; LET="R A"; fi
read -r LF LC <<<"$LET"
res() { cat "$W/res/$1.$2" 2>/dev/null || echo ERR; }
declare -A VERDICT CELLS POSCOL VERSION
N_FIXED=0 N_VULN=0 N_INC=0 N_NA=0 SELFTEST_V="(not run)" NEGCTL_V="(not run)"
for i in "${SEL[@]}"; do
  VERSION[$i]=$(cat "$W/ver/$i" 2>/dev/null || echo "(not on PATH)")
  n=${R_NAME[$i]} cells="" pos=""
  case ${STATE[$i]} in
    missing) VERDICT[$i]="INCONCLUSIVE (missing)" ;;
    setup-failed) VERDICT[$i]="INCONCLUSIVE (setup failed)" ;;
    na) if [ "$MODE" = offline ]; then VERDICT[$i]="N/A (live-only)"; else VERDICT[$i]="N/A (offline-only)"; fi ;;
    run)
      bad_ok=0 bad_no=0 bad_other=0 pos_ok=1
      for g in "${GROUPS_SEEN[@]}"; do
        a=0 r=0 o=0
        for ((j = 0; j < NB; j++)); do
          [ "${T_GROUP[$j]}" = "$g" ] || continue
          case $(res "$i" "$j") in "$OKV") a=$((a + 1)) ;; "$NOV") r=$((r + 1)) ;; *) o=$((o + 1)) ;; esac
        done
        cells+="${r}${LF}/${a}${LC}/${o}?|"; bad_ok=$((bad_ok + a)); bad_no=$((bad_no + r)); bad_other=$((bad_other + o))
      done
      for ((j = NB; j < NT; j++)); do
        s=$(res "$i" "$j"); [ "$s" = "$OKV" ] && s=OK || pos_ok=0; pos+="${pos:+,}$s"
      done
      if [ "$n" = NEGCONTROL ]; then
        if [ $bad_ok -eq "$NB" ] && [ $pos_ok -eq 1 ]; then VERDICT[$i]=VULNERABLE; else VERDICT[$i]="BROKEN ($bad_ok/$NB accepted)"; fi
      elif [ $bad_ok -gt 0 ]; then VERDICT[$i]=VULNERABLE
      elif [ $bad_other -eq 0 ] && [ $pos_ok -eq 1 ]; then VERDICT[$i]=FIXED
      elif [ $pos_ok -eq 0 ]; then VERDICT[$i]="INCONCLUSIVE (positive failed)"
      else VERDICT[$i]=INCONCLUSIVE; fi ;;
  esac
  CELLS[$i]=$cells POSCOL[$i]=$pos
  case $n in
    SELFTEST) SELFTEST_V=${VERDICT[$i]} ;;
    NEGCONTROL) NEGCTL_V=${VERDICT[$i]} ;;
    *) case ${VERDICT[$i]} in FIXED) N_FIXED=$((N_FIXED + 1)) ;; VULNERABLE) N_VULN=$((N_VULN + 1)) ;;
         N/A*) N_NA=$((N_NA + 1)) ;; *) N_INC=$((N_INC + 1)) ;; esac ;;
  esac
done
if [ "$SELFTEST_V" != FIXED ] || [ "$NEGCTL_V" != VULNERABLE ]; then RC=3
elif [ $N_VULN -gt 0 ]; then RC=2
elif [ $N_INC -gt 0 ]; then RC=1
else RC=0; fi
RUNTIME=$(( ($(date +%s%3N) - START_MS) / 100 )); RUNTIME="$((RUNTIME / 10)).$((RUNTIME % 10))"

# ---------------------------------------------------------------- report
hdr=$(printf '%-15s | %-28s' client version); sep="----------------+-----------------------------"
for g in "${GROUPS_SEEN[@]}"; do hdr+=$(printf ' | %-11s' "$g"); sep+="+-------------"; done
hdr+=$(printf ' | %-19s | %s' positive verdict); sep+="+---------------------+--------------"
echo; echo "$hdr"; echo "$sep"
for i in "${SEL[@]}"; do
  line=$(printf '%-15s | %-28s' "${R_NAME[$i]}" "${VERSION[$i]}")
  IFS='|' read -r -a cs <<<"${CELLS[$i]}"
  for ((k = 0; k < ${#GROUPS_SEEN[@]}; k++)); do line+=$(printf ' | %-11s' "${cs[$k]:--}"); done
  line+=$(printf ' | %-19s | %s' "${POSCOL[$i]:--}" "${VERDICT[$i]}")
  echo "$line"
done
echo
if [ "$MODE" = live ]; then
  echo "cells: <cert-fail>F/<connected>C/<other>? per target group (targets.txt); positive: $(IFS=,; echo "${P_HOST[*]}")"
else
  echo "cells: <rejected>R/<accepted>A/<other>? per target group, over chains/bad; positive: chains/good ($(IFS=,; echo "${P_HOST[*]}"))"
  echo "what each offline row proves:"
  for i in "${SEL[@]}"; do printf '  %-15s %s\n' "${R_NAME[$i]}" "${R_PROOF[$i]}"; done
fi
[ -n "$EXPIRY_NOTE" ] && echo "$EXPIRY_NOTE"
echo "SUMMARY: FIXED=$N_FIXED VULNERABLE=$N_VULN INCONCLUSIVE=$N_INC N/A=$N_NA   SELFTEST=$SELFTEST_V (must be FIXED)   NEGCONTROL=$NEGCTL_V (must be VULNERABLE)"
echo "runtime: ${RUNTIME}s   exit: $RC"

if [ "$DETAILS" != none ]; then
  echo; echo "=== details ==="
  for i in "${SEL[@]}"; do
    f=$W/setup.${R_SETUP[$i]:-none}.log
    [ "${STATE[$i]}" = setup-failed ] && [ -s "$f" ] && { echo "### ${R_NAME[$i]} setup (${R_SETUP[$i]})"; sed 's/^/    /' "$f" | head -20; }
    [ "${STATE[$i]}" = run ] || continue
    if [ "$DETAILS" = fail ]; then
      case ${R_NAME[$i]}:${VERDICT[$i]} in *:FIXED|NEGCONTROL:VULNERABLE) continue ;; esac
    fi
    for ((j = 0; j < NT; j++)); do
      echo "### ${R_NAME[$i]}  ${ALL_HOST[$j]}  => $(res "$i" "$j")"; sed 's/^/    /' "$W/raw/$i.$j" 2>/dev/null | head -8
    done
  done
fi

if [ -n "$JSON" ]; then
  {
    printf '{"harness":"tests/tls-trust","profile":%s,"mode":%s,"pkgs_commit":%s,' \
      "$(json_str "$(basename "$PROFILE")")" "$(json_str "$MODE")" "$(json_str "${PIN:-}")"
    printf '"timestamp":%s,"verify_at":%s,"jobs":%s,"timeout_s":%s,"runtime_s":%s,' \
      "$(json_str "$(date -u +%Y-%m-%dT%H:%M:%SZ)")" "$(json_str "$VERIFY_AT_ISO")" "$JOBS" "$TIMEOUT" "$RUNTIME"
    printf '"selftest":%s,"negcontrol":%s,"exit_code":%s,' "$(json_str "$SELFTEST_V")" "$(json_str "$NEGCTL_V")" "$RC"
    printf '"earliest_target_leaf_expiry":%s,"expiry_warning":%s,' \
      "$(json_str "$([ -n "$EARLIEST_EXPIRY" ] && date -u -d "@$EARLIEST_EXPIRY" +%Y-%m-%dT%H:%M:%SZ)")" "$(json_str "$EXPIRY_NOTE")"
    printf '"summary":{"FIXED":%s,"VULNERABLE":%s,"INCONCLUSIVE":%s,"NA":%s},"rows":[' $N_FIXED $N_VULN $N_INC $N_NA
    first=1
    for i in "${SEL[@]}"; do
      [ $first = 1 ] || printf ','; first=0
      printf '{"client":%s,"version":%s,"mode":%s,"proof":%s,"verdict":%s,"results":{' \
        "$(json_str "${R_NAME[$i]}")" "$(json_str "${VERSION[$i]}")" "$(json_str "$MODE")" \
        "$(json_str "$([ "$MODE" = live ] && echo "live: TLS handshake + HTTP request" || echo "${R_PROOF[$i]}")")" "$(json_str "${VERDICT[$i]}")"
      if [ "${STATE[$i]}" = run ]; then
        for ((j = 0; j < NT; j++)); do
          [ $j = 0 ] || printf ','; printf '%s:%s' "$(json_str "${ALL_HOST[$j]}")" "$(json_str "$(res "$i" "$j")")"
        done
      fi
      printf '}}'
    done
    printf ']}\n'
  } > "$W/out.json"
  if [ "$JSON" = - ]; then echo; echo "=== json ==="; cat "$W/out.json"; else cp "$W/out.json" "$JSON"; fi
fi
exit $RC
