#!/bin/sh
set -eo pipefail
shopt -s inherit_errexit

cd `dirname $0`

export PROJECT=libffi
export GITHUB_REPO=libffi/libffi
export TAG=`../scripts/get-latest-github-release-tag.sh $GITHUB_REPO`
# Clamp to v3.4.2 release until issues with later releases are resolved:
# https://github.com/gnustep/libs-base/issues/278
# export TAG=v3.4.2

# load environment and prepare project
../scripts/common.bat prepare_project

cd "$SRCROOT/$PROJECT" || exit /b 1

if [ ! -f configure ]; then
  echo
  echo "### Running autogen"
  ./autogen.sh
fi

echo
echo "### Running configure"
MSVCC="$PWD/msvcc.sh -g"
if [ "$ARCH" == "x86" ]; then
  MSVCC="$MSVCC -m32"
  FFI_BUILD=i686-pc-cygwin # cygwin suffix required for building DLL
  FFI_HOST=i686-pc-cygwin
elif [ "$ARCH" == "x64" ]; then
  MSVCC="$MSVCC -m64"
  FFI_BUILD=x86_64-pc-cygwin
  FFI_HOST=x86_64-pc-cygwin
elif [ "$ARCH" == "arm64" ]; then
  MSVCC="$MSVCC -marm64"
  FFI_BUILD=x86_64-pc-cygwin # build tools are x64-hosted
  FFI_HOST=arm64-pc-cygwin
else
  echo Unknown ARCH: $ARCH && exit 1
fi
if [ "$BUILD_TYPE" == "Debug" ]; then
  MSVCC="$MSVCC -DUSE_DEBUG_RTL"
fi
rm -rf $FFI_HOST
./configure \
  --build=$FFI_BUILD --host=$FFI_HOST \
  --prefix="$UNIX_INSTALL_PREFIX" \
  --disable-docs \
  CC="$MSVCC" CXX="$MSVCC" LD=link \
  CPP="cl -nologo -EP" CXXCPP="cl -nologo -EP" \
  CPPFLAGS="-DFFI_BUILDING_DLL" LDFLAGS="" \

echo
echo "### Building"
make -j "${BUILD_THREADS:-`nproc`}"

echo
echo "### Installing"
# make install throws errors for DLL builds, so we install manually instead
cd $TARGET
install -D -t "$UNIX_INSTALL_PREFIX"/lib/pkgconfig/ *.pc
install -D -t "$UNIX_INSTALL_PREFIX"/include/ include/*.h
install -D -t "$UNIX_INSTALL_PREFIX"/bin/ .libs/libffi-*.dll
install -D -t "$UNIX_INSTALL_PREFIX"/bin/ .libs/libffi-*.pdb
install .libs/libffi-*.lib "$UNIX_INSTALL_PREFIX"/lib/ffi.lib
