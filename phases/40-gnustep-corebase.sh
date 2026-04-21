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

GNUSTEP_CC="`gnustep-config --variable=CC`"
GNUSTEP_CPP="`gnustep-config --variable=CPP`"
GNUSTEP_CXX="`gnustep-config --variable=CXX`"

./configure \
  --build=$CONFIGURE_BUILD \
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
make -j "${BUILD_THREADS:-`nproc`}" --output-sync=target CC="$GNUSTEP_CC" CXX="$GNUSTEP_CXX"

echo
echo "### Installing"
make install
