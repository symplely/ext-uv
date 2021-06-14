@echo off
if not defined PHP_VER set PHP_VER=8.0.7
if not defined LIBUV_VER set LIBUV_VER=v1.41.1
if not defined UV_SHARED set UV_SHARED=--with-uv

IF NOT EXIST php-sdk (
  curl -L https://github.com/microsoft/php-sdk-binary-tools/archive/refs/tags/php-sdk-2.2.0.tar.gz | tar xzf - && ren php-sdk-binary-tools-php-sdk-2.2.0 php-sdk
)

IF NOT EXIST php-sdk\phpdev\vs16\x64 (mkdir php-sdk\phpdev\vs16\x64)
IF NOT EXIST php-sdk\phpdev\vs16\x64\pecl (mkdir php-sdk\phpdev\vs16\x64\pecl)
IF NOT EXIST php-sdk\phpdev\vs16\x64\pecl\uv (mklink /j "php-sdk\phpdev\vs16\x64\pecl\uv" .)

cd php-sdk\phpdev\vs16\x64
IF NOT EXIST php-%PHP_VER% (curl -L https://github.com/php/php-src/archive/refs/tags/php-%PHP_VER%.tar.gz | tar xzf -)
IF EXIST php-src-php-%PHP_VER% ren php-src-php-%PHP_VER% php-%PHP_VER%

cd ..\..\..
set "VSCMD_START_DIR=%CD%"
set "__VSCMD_ARG_NO_LOGO=yes"
set PHP_SDK_ROOT_PATH=%~dp0
set PHP_SDK_ROOT_PATH=%PHP_SDK_ROOT_PATH:~0,-1%

set PHP_SDK_RUN_FROM_ROOT=.\php-sdk
set CRT=vs16
set ARCH=x64
copy /Y ..\cmd\phpsdk_setshell.bat bin\phpsdk_setshell.bat
bin\phpsdk_setshell.bat vs16 x64 && bin\phpsdk_setvars.bat && bin\phpsdk_dumpenv.bat && bin\phpsdk_buildtree.bat phpdev && cd php-%PHP_VER% && IF NOT EXIST config.nice (..\..\..\..\bin\phpsdk_deps -u --no-backup) && IF NOT EXIST "..\deps\include\uv" (
  cd .. && curl -L https://github.com/symplely/libuv/releases/download/libuv-%LIBUV_VER%-windows/libuv-%LIBUV_VER%.zip --output libuv-%LIBUV_VER%.zip && unzip -xoq libuv-%LIBUV_VER%.zip && copy /Y libuv-%LIBUV_VER%\bin\* deps\bin\ && copy /Y libuv-%LIBUV_VER%\include\* deps\include\ && mkdir deps\include\uv && copy /Y libuv-%LIBUV_VER%\include\uv\* deps\include\uv\ && copy /Y libuv-%LIBUV_VER%\lib\* deps\lib\ && del libuv-%LIBUV_VER%.zip && rmdir /S /Q libuv-%LIBUV_VER% && copy /Y "C:\Program Files (x86)\Windows Kits\10\Lib\10.0.19041.0\um\x64\UserEnv.Lib" deps\lib\ && copy /Y "C:\Program Files (x86)\Windows Kits\10\Include\10.0.19041.0\um\UserEnv.h" deps\include\ && cd php-%PHP_VER% && buildconf --add-modules-dir=..\pecl\ && configure --enable-cli %UV_SHARED% --enable-sockets && nmake snap && cd ..\..\..\..\..
) else (
  buildconf --force --add-modules-dir=..\pecl\ && configure --enable-cli %UV_SHARED% --enable-sockets && nmake snap && cd ..\..\..\..\..
)
