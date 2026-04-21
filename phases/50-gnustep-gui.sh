#!/bin/sh
set -eo pipefail
shopt -s inherit_errexit

cd `dirname $0`

export PROJECT=gnustep-gui
export GITHUB_REPO=flexibits/gnustep-libs-gui
export TAG=

# load environment and prepare project
../scripts/common.bat prepare_project

cd "$SRCROOT/$PROJECT"

echo
echo "### Loading GNUstep environment"
. "$UNIX_INSTALL_PREFIX/share/GNUstep/Makefiles/GNUstep.sh"

if [ "$ARCH" = "arm64" ]; then
  CLANG_TARGET="--target=aarch64-pc-windows-msvc"
else
  CLANG_TARGET="--target=x86_64-pc-windows-msvc"
fi

GNUSTEP_CC="`gnustep-config --variable=CC` $CLANG_TARGET"
GNUSTEP_CPP="`gnustep-config --variable=CPP` $CLANG_TARGET"
GNUSTEP_CXX="`gnustep-config --variable=CXX` $CLANG_TARGET"

echo
echo "### Running configure"
./configure \
  --build=$TARGET --host=$TARGET \
  `# specify environment since it doesn't use gnustep-config to get these` \
  CC="$GNUSTEP_CC" \
  CPP="$GNUSTEP_CPP" \
  CXX="$GNUSTEP_CXX" \
  CFLAGS="$CFLAGS -I$UNIX_INSTALL_PREFIX/include" \
  CPPFLAGS="$CPPFLAGS -I$UNIX_INSTALL_PREFIX/include" \
  LDFLAGS="$LDFLAGS -L$UNIX_INSTALL_PREFIX/lib" \

echo
echo "### Building"
make -j "${BUILD_THREADS:-`nproc`}" --output-sync=target CC="$GNUSTEP_CC" CXX="$GNUSTEP_CXX" || bash

echo
echo "### Installing"
make install
