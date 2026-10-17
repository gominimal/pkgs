#!/bin/bash
# x86_64 entry point. The bedrock sysroot's libc looks for its iconv modules in /usr/lib/gconv, which in
# the sandbox holds production glibc's; GHC's text encodings (mkTextEncoding) need the sysroot's own.
export GCONV_PATH=/usr/lib/glibc-bedrock-2.42/lib/gconv
exec ./build.sh
