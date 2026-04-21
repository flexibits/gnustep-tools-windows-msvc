#!/bin/sh
set -eo pipefail
shopt -s inherit_errexit

cd `dirname $0`

export PROJECT=gnustep-corebase
export GITHUB_REPO=flexibits/gnustep-libs-corebase
export TAG=

# load environment and prepare project
../scripts/common.bat prepare_project

cd "$SRCROOT/$PROJECT"

echo
echo "### Loading GNUstep environment"
. "$UNIX_INSTALL_PREFIX/share/GNUstep/Makefiles/GNUstep.sh"

echo
echo "### Running configure"

# gnustep-config --variable=CC returns only the binary path; the target triple
# must be appended explicitly, same as in gnustep-make.sh.
if [ "$ARCH" = "arm64" ]; then
  CLANG_TARGET="--target=aarch64-pc-windows-msvc"
else
  CLANG_TARGET="--target=x86_64-pc-windows-msvc"
fi

GNUSTEP_CC="`gnustep-config --variable=CC` $CLANG_TARGET"
GNUSTEP_CPP="`gnustep-config --variable=CPP` $CLANG_TARGET"
GNUSTEP_CXX="`gnustep-config --variable=CXX` $CLANG_TARGET"

./configure \
  --host=$TARGET \
  --disable-cfrunloop \
  --disable-windows-icu \
  `# specify environment since it doesn't use gnustep-config to get these` \
  CC="$GNUSTEP_CC" \
  CPP="$GNUSTEP_CPP" \
  CXX="$GNUSTEP_CXX" \
  CFLAGS="$CFLAGS -I$UNIX_INSTALL_PREFIX/include" \
  CPPFLAGS="$CPPFLAGS -I$UNIX_INSTALL_PREFIX/include" \
  LDFLAGS="$LDFLAGS -L$UNIX_INSTALL_PREFIX/lib" \

echo
echo "### Building"
# Pass CC/CXX explicitly: gnustep-make's rules use their stored CC (binary only),
# not the value from configure, so the target triple must be overridden here too.
make -j "${BUILD_THREADS:-`nproc`}" --output-sync=target CC="$GNUSTEP_CC" CXX="$GNUSTEP_CXX"

echo
echo "### Installing"
make install
