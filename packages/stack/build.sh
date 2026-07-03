#!/bin/bash
set -euo pipefail

# `cabal update` (the hackage index) and `cabal build` (stack's full dependency
# tree) both fetch from hackage.haskell.org live during the build, and those
# downloads flake intermittently (truncated reads). cabal verifies sha256s and
# caches deps under ~/.cabal, so a retry re-fetches only what failed and
# resumes. The hermetic fix is a cabal.project.freeze + a vendored local
# package repo (a bigger job) -- this retry is the cheap stopgap.
retry() {
    local -i attempt=1 max=4
    until "$@"; do
        if (( attempt >= max )); then
            echo "retry: '$*' failed after $max attempts" >&2
            return 1
        fi
        echo "retry: '$*' failed (attempt $attempt/$max) -- likely a transient hackage fetch; retrying in $(( attempt * 15 ))s" >&2
        sleep $(( attempt * 15 ))
        attempt+=1
    done
}

if [ -f Setup.hs ]; then
  echo '{-# LANGUAGE CPP #-}' > Setup.hs.tmp
  while IFS= read -r line; do
    if [[ "$line" == *"import           Distribution.Utils.Path ( interpretSymbolicPathCWD )"* ]]; then
      echo "#if MIN_VERSION_Cabal(3,14,0)" >> Setup.hs.tmp
      echo "import           Distribution.Utils.Path ( interpretSymbolicPathCWD )" >> Setup.hs.tmp
      echo "#endif" >> Setup.hs.tmp
    elif [[ "$line" == *"main :: IO ()"* ]]; then
      echo "#if !MIN_VERSION_Cabal(3,14,0)" >> Setup.hs.tmp
      echo "interpretSymbolicPathCWD :: FilePath -> FilePath" >> Setup.hs.tmp
      echo "interpretSymbolicPathCWD = id" >> Setup.hs.tmp
      echo "#endif" >> Setup.hs.tmp
      echo "" >> Setup.hs.tmp
      echo "$line" >> Setup.hs.tmp
    else
      echo "$line" >> Setup.hs.tmp
    fi
  done < Setup.hs
  mv Setup.hs.tmp Setup.hs
fi

if [ -f stack.cabal ]; then
  sed -i 's/Cabal >=3.14 \&\& <3.18/Cabal >=3.12 \&\& <3.18/g' stack.cabal
fi

if [ -f cabal.config ]; then
  sed -i '/unix ==/d' cabal.config
  sed -i '/Cabal ==/d' cabal.config
  sed -i '/Cabal-syntax ==/d' cabal.config
fi

retry cabal update
retry cabal build

# Install stack binary
mkdir -p "$OUTPUT_DIR"/usr/bin
cp -v "$(cabal list-bin stack)" "$OUTPUT_DIR"/usr/bin/

# Install man pages
mkdir -p "$OUTPUT_DIR"/usr/share/man/man1
cp -v doc/man/stack.1 "$OUTPUT_DIR"/usr/share/man/man1/ 2>/dev/null || true

# Install documentation
mkdir -p "$OUTPUT_DIR"/usr/share/doc/stack
cp -v doc/README.md "$OUTPUT_DIR"/usr/share/doc/stack/ 2>/dev/null || true
