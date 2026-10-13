@echo off
setlocal

set PROJECT=libjpeg
set GITHUB_REPO=libjpeg-turbo/libjpeg-turbo
set TAG=3.1.90

:: get the latest release tag from GitHub
cd %~dp0
for /f "usebackq delims=" %%i in (`call %BASH% '../scripts/get-latest-github-release-tag.sh %GITHUB_REPO%'`) do (
  set TAG=%%i
)

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
  -D ENABLE_STATIC=OFF -D INST_ID=vc ^
  || exit /b 1

echo.
echo ### Building [%time%]
ninja || exit /b 1

echo.
echo ### Installing [%time%]
ninja install || exit /b 1

if errorlevel 1 exit /b 1
call "%~dp0\..\scripts\common.bat" cache_store
