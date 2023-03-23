@echo off
if not defined PHP_VER set PHP_VER=8.2.4
if not defined UV_SHARED set UV_SHARED=--with-uv

if "%PHP_VER%" == "7.4.33" (
    set CRT=vc15
) else (
    set CRT=vs16
)

IF NOT EXIST php-sdk (
  curl -L https://github.com/microsoft/php-sdk-binary-tools/archive/refs/tags/php-sdk-2.2.0.tar.gz | tar xzf - && ren php-sdk-binary-tools-php-sdk-2.2.0 php-sdk
)

IF NOT EXIST php-sdk\phpdev\%CRT%\x64 (mkdir php-sdk\phpdev\%CRT%\x64)
IF NOT EXIST php-sdk\phpdev\%CRT%\x64\pecl (mkdir php-sdk\phpdev\%CRT%\x64\pecl)
IF NOT EXIST php-sdk\phpdev\%CRT%\x64\pecl\uv (mklink /j "php-sdk\phpdev\%CRT%\x64\pecl\uv" .)

cd php-sdk\phpdev\%CRT%\x64
IF EXIST php-src-php-%PHP_VER% ren php-src-php-%PHP_VER% php-%PHP_VER%
IF NOT EXIST php-%PHP_VER% (
    curl -L https://github.com/php/php-src/archive/refs/tags/php-%PHP_VER%.tar.gz | tar xzf -
    IF EXIST php-src-php-%PHP_VER% ren php-src-php-%PHP_VER% php-%PHP_VER%
)

cd ..\..\..
set "VSCMD_START_DIR=%CD%"
set "__VSCMD_ARG_NO_LOGO=yes"
set PHP_SDK_ROOT_PATH=%~dp0
set PHP_SDK_ROOT_PATH=%PHP_SDK_ROOT_PATH:~0,-1%

set PHP_SDK_RUN_FROM_ROOT=.\php-sdk
set ARCH=x64
rem copy /Y ..\cmd\phpsdk_setshell.bat bin\phpsdk_setshell.bat
bin\phpsdk_setshell.bat %CRT% x64 && bin\phpsdk_setvars.bat && bin\phpsdk_dumpenv.bat && bin\phpsdk_buildtree.bat phpdev && cd php-%PHP_VER% && IF NOT EXIST config.nice (..\..\..\..\bin\phpsdk_deps -u --no-backup) && IF NOT EXIST "..\deps\include\uv" (
  cd .. && ..\..\..\..\cmd\libuv_build.bat && cd php-%PHP_VER% && buildconf --add-modules-dir=..\pecl\ && configure --enable-cli %UV_SHARED% --enable-sockets && nmake snap && cd ..\..\..\..\.. && if EXIST config.w32.bak ( ren config.w32 config.w32.shared && ren config.w32.bak config.w32)
) else (
  buildconf --force --add-modules-dir=..\pecl\ && configure --enable-cli %UV_SHARED% --enable-sockets && nmake snap && cd ..\..\..\..\.. && if EXIST config.w32.bak ( ren config.w32 config.w32.shared && ren config.w32.bak config.w32)
)
