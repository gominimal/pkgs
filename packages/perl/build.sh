#!/bin/sh
set -e

tar -xof perl-5.44.0.tar.xz
cd perl-5.44.0

export BUILD_ZLIB=False
export BUILD_BZIP2=0
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Perl's Configure recomputes cf_time from `date` UNCONDITIONALLY, so a
# `-D cf_time=` override does NOT stick — the wall-clock still leaks into cf_time,
# which feeds $config_tag1 (perlbug/perlthanks) and the "Configuration time" line
# in Config_heavy.pl. config.over is sourced AFTER all of Configure's computation
# (perl's documented override hook), so pin cf_time/cf_by there instead.
# The sandbox already exports SOURCE_DATE_EPOCH — read it (with a fallback), don't re-set it.
CF_TIME="$(LC_ALL=C TZ=UTC date -u -d "@${SOURCE_DATE_EPOCH:-0}" 2>/dev/null || echo 'Thu Jan  1 00:00:00 UTC 1970')"
# Configure also bakes the build host's nodename (in the sandbox a per-build
# `minimal-<pid>` hostname) into several Config fields: myuname (the "Target
# system" line, via `uname -a`), myhostname, and the derived cf_email/perladmin.
# config.over is sourced after all computation, so pin every host-derived field
# here. myuname keeps the real kernel info with just the nodename sanitized.
MYUNAME="$(uname -a | awk '{$2="builder"; print}' | tr '[:upper:]' '[:lower:]' | tr -d '/')"
cat > config.over <<EOF
cf_time='$CF_TIME'
cf_by='builder'
myuname='$MYUNAME'
myhostname='builder'
cf_email='build@builder'
perladmin='build@builder'
EOF

sh Configure  -des                                          \
             -D cc=gcc                                     \
             -D prefix=/usr                                 \
             -D vendorprefix=/usr                           \
             -D privlib=/usr/lib/perl5/5.42/core_perl      \
             -D archlib=/usr/lib/perl5/5.42/core_perl      \
             -D sitelib=/usr/lib/perl5/5.42/site_perl      \
             -D sitearch=/usr/lib/perl5/5.42/site_perl     \
             -D vendorlib=/usr/lib/perl5/5.42/vendor_perl  \
             -D vendorarch=/usr/lib/perl5/5.42/vendor_perl \
             -D man1dir=/usr/share/man/man1                \
             -D man3dir=/usr/share/man/man3                \
             -D pager="/usr/bin/less -isR"                 \
             -D useshrplib                                 \
             -D usethreads

make -j$(nproc)
# TEST_JOBS=$(nproc) make test_harness # TODO there are failures
make DESTDIR=$OUTPUT_DIR install-strip
