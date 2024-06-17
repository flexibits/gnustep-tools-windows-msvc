@echo off
setlocal

set "PROJECT=icu"
set "GITHUB_REPO=unicode-org/icu"
set "TAG=release-75-1"
set "ICU_VERSION=75.1"
set "SPARSE_CHECKOUT=icu4c"

call "%~dp0\..\scripts\common.bat" prepare_project || exit /b 1

cd "%SRCROOT%\%PROJECT%" || exit /b 1

:: write ICU configuration
set "UCONFIG_H=%SRCROOT%\%PROJECT%\icu4c\source\common\unicode\uconfig.h"
%PYTHON% "%~dp0\..\scripts\configure-icu.py" -- "%UCONFIG_H%" ^
  "U_DISABLE_RENAMING=1" ^
  || exit /b 1

:: perform build
msbuild "%SRCROOT%\%PROJECT%\icu4c\source\allinone\allinone.sln" /target:Clean
msbuild "%SRCROOT%\%PROJECT%\icu4c\source\allinone\allinone.sln" /p:Configuration=%BUILD_TYPE% /p:Platform=%ARCH% /p:SkipUWP=true

:: clear out previously installed artifacts
:: (we do this explicitly instead of overwriting because depending on ICU configuration options,
:: dlls/libs may be named differently, and certain header files may/may not exist)
call %BASH% -c "find $(cygpath '%INSTALL_PREFIX%/bin') -iname icu*.dll | xargs rm -vf"
call %BASH% -c "find $(cygpath '%INSTALL_PREFIX%/lib') -iname icu*.lib | xargs rm -vf"
call %BASH% -c "find $(cygpath '%INSTALL_PREFIX%/lib/pkgconfig') -iname icu*.pc | xargs rm -vf"
call %BASH% -c "rm -rvf '%INSTALL_PREFIX%/include/unicode'"

if "%BUILD_TYPE%"=="Debug" (
  xcopy /Y /F    "%SRCROOT%\%PROJECT%\icu4c\bin64\icudt75.dll" "%INSTALL_PREFIX%\bin\"     || exit /b 1
  xcopy /Y /F    "%SRCROOT%\%PROJECT%\icu4c\bin64\icu*75d.dll" "%INSTALL_PREFIX%\bin\"     || exit /b 1
  xcopy /Y /F    "%SRCROOT%\%PROJECT%\icu4c\lib64\icudt.lib"   "%INSTALL_PREFIX%\lib\"     || exit /b 1
  xcopy /Y /F    "%SRCROOT%\%PROJECT%\icu4c\lib64\icu*d.lib"   "%INSTALL_PREFIX%\lib\"     || exit /b 1
) else (
  xcopy /Y /F    "%SRCROOT%\%PROJECT%\icu4c\bin64\icudt75.dll" "%INSTALL_PREFIX%\bin\"     || exit /b 1
  xcopy /Y /F    "%SRCROOT%\%PROJECT%\icu4c\bin64\icu*75.dll"  "%INSTALL_PREFIX%\bin\"     || exit /b 1
  xcopy /Y /F    "%SRCROOT%\%PROJECT%\icu4c\lib64\icudt.lib"   "%INSTALL_PREFIX%\lib\"     || exit /b 1
  xcopy /Y /F    "%SRCROOT%\%PROJECT%\icu4c\lib64\icu*.lib"    "%INSTALL_PREFIX%\lib\"     || exit /b 1
)
xcopy /Y /F /S "%SRCROOT%\%PROJECT%\icu4c\include\*"        "%INSTALL_PREFIX%\include\" || exit /b 1

:: write pkgconfig files
if "%BUILD_TYPE%"=="Debug" (
  call "%~dp0\..\scripts\common.bat" write_pkgconfig icu-i18n %ICU_VERSION% "" -licuind           "" icu-uc   || exit /b 1
  call "%~dp0\..\scripts\common.bat" write_pkgconfig icu-io   %ICU_VERSION% "" -licuiod           "" icu-i18n || exit /b 1
  call "%~dp0\..\scripts\common.bat" write_pkgconfig icu-uc   %ICU_VERSION% "" "-licuucd -licudt" "" ""       || exit /b 1
) else (
  call "%~dp0\..\scripts\common.bat" write_pkgconfig icu-i18n %ICU_VERSION% "" -licuin            "" icu-uc   || exit /b 1
  call "%~dp0\..\scripts\common.bat" write_pkgconfig icu-io   %ICU_VERSION% "" -licuio            "" icu-i18n || exit /b 1
  call "%~dp0\..\scripts\common.bat" write_pkgconfig icu-uc   %ICU_VERSION% "" "-licuuc -licudt"  "" ""       || exit /b 1
)

exit /b 0
