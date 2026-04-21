#!/bin/sh
set -eo pipefail
shopt -s inherit_errexit

cd `dirname $0`

export PROJECT=gnustep-make
export GITHUB_REPO=gnustep/tools-make
export TAG=

# load environment and prepare project
../scripts/common.bat prepare_project

cd "$SRCROOT/$PROJECT"

echo
echo "### Running configure"
CONFIGURE_OPTS=
if [ "$BUILD_TYPE" == "Debug" ]; then
  CONFIGURE_OPTS=--enable-debug-by-default
fi

# clang defaults to the host (x64) target; pass the triple explicitly so the
# compiler test and gnustep-make's own makefiles target the right architecture.
if [ "$ARCH" = "arm64" ]; then
  CLANG_TARGET="--target=aarch64-pc-windows-msvc"
else
  CLANG_TARGET="--target=x86_64-pc-windows-msvc"
fi

# configure checks for _Block_copy to verify blocks runtime support. vcvars only
# puts MSVC system dirs on LIB, so we add the install prefix explicitly via LDFLAGS.
# libobjc2 is built with an embedded blocks runtime, so LIBS=-lobjc is sufficient
# to satisfy the check — the same relationship libdispatch uses for its blocks support.
./configure \
  CC="$CC $CLANG_TARGET" \
  CXX="$CXX $CLANG_TARGET" \
  LDFLAGS="$LDFLAGS -L$UNIX_INSTALL_PREFIX/lib" \
  LIBS="-lobjc" \
  --build=$TARGET --host=$TARGET \
  --host=$TARGET \
  --prefix="$UNIX_INSTALL_PREFIX" \
  --with-library-combo=ng-gnu-gnu \
  --with-runtime-abi=gnustep-2.0 \
  $CONFIGURE_OPTS

echo
echo "### Installing"
make install
