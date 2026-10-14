@echo off

:: load environment
call "%~dp0\sdkenv.bat"

:: Call subroutine passed as argument
setlocal
call :%*
exit /b %errorlevel%

:loadenv
  goto :eof

:prepare_project
  if not defined PROJECT (echo Missing PROJECT && exit /b 1)
  if not defined REPO (
    if defined GITHUB_REPO (
      set REPO=https://github.com/%GITHUB_REPO%.git
    ) else (
      echo Missing REPO && exit /b 1
    )
  )
  
  cd "%SRCROOT%"
  
  :: clone project if needed
  if not exist "%PROJECT%" (
    echo.
    echo ### Cloning project
    if "%SPARSE_CHECKOUT%"=="" (
      if not "%SHALLOW_CLONE%"=="1" (
        git clone --recursive %REPO% %PROJECT% || exit /b 1
      ) else if "%TAG%"=="" (
        git clone --recursive --depth 1 %REPO% %PROJECT% || exit /b 1
      ) else (
        git clone --recursive --depth 1 --branch %TAG% %REPO% %PROJECT% || exit /b 1
      )
    ) else (
      git clone -n --depth=1 --filter=tree:0 %REPO% %PROJECT% || exit /b 1
      cd %PROJECT% || exit /b 1
      git sparse-checkout set --no-cone "%SPARSE_CHECKOUT%" || exit /b 1
      if "%SHALLOW_CLONE%"=="1" (
        git fetch --depth 1 origin tag %TAG% || exit /b 1
      ) else (
        git fetch --tags || exit /b 1
      )
      git checkout %TAG% || exit /b 1
      cd .. || exit /b 1
    )
  )
  
  cd %PROJECT%
  
  if defined NO_CLEAN (
    echo.
    echo ### Skipping project cleanup
  ) else (
    echo.
    echo ### Cleaning project
    git reset --hard || exit /b 1
    git clean -qfdx || exit /b 1
  )
  
  if defined NO_UPDATE (
    echo.
    echo ### Skipping project update
  ) else (
    echo.
    :: check out tag/branch if any
    if not "%TAG%" == "" (
      echo ### Checking out "%TAG%"
      if "%SHALLOW_CLONE%"=="1" (
        REM TAG can be a tag or a branch, so check out what was fetched rather than a local ref
        git fetch --depth 1 origin %TAG% || exit /b 1
        git checkout -q FETCH_HEAD || exit /b 1
      ) else (
        git fetch --tags || exit /b 1
        git checkout -q %TAG% || exit /b 1
      )
    )
    
    call :update_project || exit /b 1
    
    :: update submodules if needed (also init in case submodule was added)
    git submodule sync --recursive || exit /b 1
    git submodule update --recursive --init || exit /b 1
  )
  
  for /F "tokens=*" %%P in ('dir /b /s ^"%ROOT_DIR%\patches\%PROJECT%-*.patch^" 2^>nul') do (
    echo.
    echo ### Applying %%~nxP
    git apply --ignore-whitespace %%P || exit /b 1
  )
  
  if defined ADDITIONAL_PATCHES_DIR (
    for /F "tokens=*" %%P in ('dir /b /s ^"%ADDITIONAL_PATCHES_DIR%\%PROJECT%-*.patch^" 2^>nul') do (
      echo.
      echo ### Applying %%~nxP
      git apply --ignore-whitespace %%P || exit /b 1
    )
  )
  
  goto :eof

:update_project
  :: check if we should update project
  set GIT_BRANCH=NONE
  for /f "usebackq delims=" %%i in (`git symbolic-ref --short -q HEAD`) do (
    call :set_git_branch %%i || exit /b 1
  )
  if not [%GIT_BRANCH%] == [NONE] (
    call :update_project_2 || exit /b 1
  ) else if "%TAG%" == "" (
    echo NOT updating project [not on branch]
  )
  goto :eof

:update_project_2
  :: check if current branch has a remote
  set GIT_REMOTE=NONE
  for /f "usebackq delims=" %%i in (`git config --get branch.%GIT_BRANCH%.remote`) do (
    call :set_git_remote %%i || exit /b 1
  )
  if not [%GIT_REMOTE%] == [NONE] (
    echo ### Updating project
    git pull --ff-only || exit /b 1
  ) else (
    echo ### NOT updating project [no remote for branch %GIT_BRANCH%]
  )
  goto :eof

:set_git_branch
  set GIT_BRANCH=%1
  goto :eof
  
:set_git_remote
  set GIT_REMOTE=%1
  goto :eof

:: Restore the phase's installed files from the build cache when BUILD_CACHE_DIR is set (CI).
:: Exits 0 on a hit, so the phase can skip building; otherwise the phase builds and then calls
:: cache_store. Call it once PROJECT, REPO/GITHUB_REPO and TAG are set, with the phase script's
:: path as the argument. See build-cache.ps1 for what the cache key covers.
:: (WindowsSDKVersion ends in a backslash, so it can't be last in a quoted argument.)
:cache_restore
  if not defined BUILD_CACHE_DIR exit /b 1
  if not defined REPO set "REPO=https://github.com/%GITHUB_REPO%.git"
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-cache.ps1" -Action Restore ^
    -CacheDir "%BUILD_CACHE_DIR%" -Name %PROJECT%-%ARCH%-%BUILD_TYPE% ^
    -InstallPrefix "%INSTALL_PREFIX%" -StateDir "%INSTALL_PREFIX%.cache" ^
    -Repo "%REPO%" -Ref "%TAG%" ^
    -Inputs "%~f1;%~dp0common.bat;%~dp0sdkenv.bat;%~dp0*.py;%ROOT_DIR%\patches\%PROJECT%-*.patch;%cmake_toolchain_file%" ^
    -Extra "%WindowsSDKVersion%;%ARCH%;%BUILD_TYPE%;%VCToolsVersion%;%VSCMD_VER%"
  exit /b %errorlevel%

:: Store the files the phase installed in the build cache, after a cache_restore miss
:cache_store
  if not defined BUILD_CACHE_DIR exit /b 0
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-cache.ps1" -Action Store ^
    -CacheDir "%BUILD_CACHE_DIR%" -Name %PROJECT%-%ARCH%-%BUILD_TYPE% ^
    -InstallPrefix "%INSTALL_PREFIX%" -StateDir "%INSTALL_PREFIX%.cache" ^
    || echo WARNING: Couldn't store %PROJECT% in the build cache
  exit /b 0

:write_pkgconfig
  set PKGCONFIG_NAME=%~1
  set PKGCONFIG_VERSION=%~2
  set PKGCONFIG_CFLAGS=%~3
  set PKGCONFIG_LIBS=%~4
  set PKGCONFIG_LIBS_PRIVATE=%~5
  set PKGCONFIG_REQUIRES=%~6
  
  :: trim version prefix
  call :trim_pkgconfig_version || exit /b 1
  
  :: use forward slashes for prefix path
  set PKGCONFIG_PREFIX=%INSTALL_PREFIX:\=/%
  
  if not exist "%INSTALL_PREFIX%\lib\pkgconfig" (mkdir "%INSTALL_PREFIX%\lib\pkgconfig" || exit /b 1)
  
  echo Writing pkgconfig file...
  (
    echo prefix=%PKGCONFIG_PREFIX%
    echo exec_prefix=${prefix}
    echo libdir=${exec_prefix}/lib
    echo includedir=${prefix}/include
    echo.
    echo Name: %PKGCONFIG_NAME%
    echo Version: %PKGCONFIG_VERSION%
    echo Description: %PKGCONFIG_NAME%
    echo Requires: %PKGCONFIG_REQUIRES%
    echo.
    echo Cflags: -I${includedir} %PKGCONFIG_CFLAGS%
    echo Libs: -L${libdir} %PKGCONFIG_LIBS%
    echo Libs.private: %PKGCONFIG_LIBS_PRIVATE%
  ) > %INSTALL_PREFIX%\lib\pkgconfig\%PKGCONFIG_NAME%.pc
  goto :eof

:: trims prefix like "v" or "release-" from PKGCONFIG_VERSION
:: and converts underscore version number delimiters to periods
:trim_pkgconfig_version
  echo %PKGCONFIG_VERSION:~0,1% | findstr /r [a-z_-] > nul
  if %errorlevel% == 0 (
    set PKGCONFIG_VERSION=%PKGCONFIG_VERSION:~1%
    call :trim_pkgconfig_version || exit /b 1
  ) else (
    set PKGCONFIG_VERSION=%PKGCONFIG_VERSION:_=.%
  )
  exit /b 0
