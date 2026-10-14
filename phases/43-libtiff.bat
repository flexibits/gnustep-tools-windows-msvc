@echo off
setlocal

set PROJECT=libtiff
set REPO=https://gitlab.com/libtiff/libtiff.git
set TAG=v4.5.0

:: load environment and prepare project
:: skip building if the build cache (CI) already has this build; see scripts\build-cache.ps1
call "%~dp0\..\scripts\common.bat" cache_restore "%~f0" && exit /b 0

call "%~dp0\..\scripts\common.bat" prepare_project || exit /b 1

set BUILD_DIR="%SRCROOT%\%PROJECT%\build-%ARCH%-%BUILD_TYPE%"
if exist "%BUILD_DIR%" (rmdir /S /Q "%BUILD_DIR%" || exit /b 1)
mkdir "%BUILD_DIR%" || exit /b 1
cd "%BUILD_DIR%" || exit /b 1

echo.
echo ### Running cmake [%time%]
cmake .. %CMAKE_OPTIONS% ^
  -D tiff-tools=OFF ^
  -D tiff-tests=OFF ^
  -D tiff-contrib=OFF ^
  -D tiff-docs=OFF ^
  -D cxx=OFF ^
  || exit /b 1

echo.
echo ### Building [%time%]
ninja || exit /b 1

echo.
echo ### Installing [%time%]
ninja install || exit /b 1

:: rename tiffd.lib to tiff.lib to allow linking using -ltiff
cd "%INSTALL_PREFIX%\lib"
if exist tiffd.lib move /y tiffd.lib tiff.lib

if errorlevel 1 exit /b 1
call "%~dp0\..\scripts\common.bat" cache_store
