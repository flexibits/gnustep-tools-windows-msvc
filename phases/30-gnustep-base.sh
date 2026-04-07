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

if [[ -z ${SKIP_CONFIGURE+0} ]];
then {
    echo
    echo "### Running configure"
    ./configure \
      --host=$TARGET \
      --disable-tls \
      --disable-windows-icu \
      $GNUSTEP_BASE_OPTIONS
};
fi

echo
echo "### Building"
make -j "${BUILD_THREADS:-`nproc`}"

echo
echo "### Installing"
make install
