#!/bin/sh
set -eo pipefail
shopt -s inherit_errexit

cd `dirname $0`

export PROJECT=gnustep-base
export GITHUB_REPO=flexibits/gnustep-libs-base
export TAG=

# load environment and prepare project
../scripts/common.bat prepare_project

cd "$SRCROOT/$PROJECT"

# Enable frame pointers for profiling/debugging support
# see https://dhashe.com/how-to-build-highly-debuggable-c-binaries.html#enable-frame-pointers-for-all-functions
export CFLAGS="$CFLAGS -fno-omit-frame-pointer"
export CXXFLAGS="$CXXFLAGS -fno-omit-frame-pointer"
export OBJCFLAGS="$OBJCFLAGS -fno-omit-frame-pointer"
export OBJCXXFLAGS="$OBJCXXFLAGS -fno-omit-frame-pointer"

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

if [[ -z ${SKIP_CONFIGURE+0} ]];
then {
    echo
    echo "### Running configure"
    ./configure \
      --host=$TARGET \
      --disable-tls \
      --disable-windows-icu \
      CC="$GNUSTEP_CC" \
      CPP="$GNUSTEP_CPP" \
      CXX="$GNUSTEP_CXX" \
      $GNUSTEP_BASE_OPTIONS
};
fi

echo
echo "### Building"
make -j "${BUILD_THREADS:-`nproc`}" --output-sync=target CC="$GNUSTEP_CC" CXX="$GNUSTEP_CXX"

echo
echo "### Installing"
make install
