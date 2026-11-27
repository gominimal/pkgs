#!/bin/sh
# jdk-21: OpenJDK from source. The build is ../jdk/build-from-source.sh, shared with the other
# from-source JDKs; this package's build_args (version, build_num, feature, boot, version_opt) select it.
exec bash ./build-from-source.sh
