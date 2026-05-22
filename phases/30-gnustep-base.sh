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

GNUSTEP_CC="`gnustep-config --variable=CC`"
GNUSTEP_CPP="`gnustep-config --variable=CPP`"
GNUSTEP_CXX="`gnustep-config --variable=CXX`"

if [[ -z ${SKIP_CONFIGURE+0} ]];
then {
    echo
    echo "### Running configure"
    ./configure \
      --build=$CONFIGURE_BUILD \
      --host=$TARGET \
      --disable-tls \
      --disable-windows-icu \
      CC="$GNUSTEP_CC" \
      CPP="$GNUSTEP_CPP" \
      CXX="$GNUSTEP_CXX" \
      CFLAGS="$CFLAGS -I$UNIX_INSTALL_PREFIX/include" \
      CPPFLAGS="$CPPFLAGS -I$UNIX_INSTALL_PREFIX/include" \
      LDFLAGS="$LDFLAGS -L$UNIX_INSTALL_PREFIX/lib" \
      $GNUSTEP_BASE_OPTIONS
};
fi

echo
echo "### Building"
make -j "${BUILD_THREADS:-`nproc`}" --output-sync=target CC="$GNUSTEP_CC" CXX="$GNUSTEP_CXX"

echo
echo "### Installing"
make install
