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

CC="clang -m64"
CPP="clang++ -m64"
CXX="clang++ -m64"

./configure \
  --build=$TARGET --host=$TARGET \
  --prefix="$UNIX_INSTALL_PREFIX" \
  --with-library-combo=ng-gnu-gnu \
  --with-runtime-abi=gnustep-2.0 \
  $CONFIGURE_OPTS
  # CC="$MSVCC" CXX="$MSVCC" LD=link \
  # CPP="cl -nologo -EP" CXXCPP="cl -nologo -EP" \
  # CPPFLAGS="-DFFI_BUILDING_DLL" LDFLAGS="" \

echo
echo "### Installing"
make install
