@echo off
IF NOT EXIST php-sdk (curl -L https://github.com/microsoft/php-sdk-binary-tools/archive/refs/tags/php-sdk-2.2.0.tar.gz | tar xzf - && ren php-sdk-binary-tools-php-sdk-2.2.0 php-sdk )

IF NOT EXIST php-sdk\phpdev\vs16\x64 (mkdir php-sdk\phpdev\vs16\x64)
IF NOT EXIST php-sdk\phpdev\vs16\x64\pecl (mkdir php-sdk\phpdev\vs16\x64\pecl)
IF NOT EXIST php-sdk\phpdev\vs16\x64\pecl\uv (mklink /j "php-sdk\phpdev\vs16\x64\pecl\uv" .)

cd php-sdk\phpdev\vs16\x64
IF NOT EXIST php-8.0.7 (curl -L https://www.php.net/distributions/php-8.0.7.tar.gz | tar xzf -)

cd ..\..\..
set "VSCMD_START_DIR=%CD%"
set "__VSCMD_ARG_NO_LOGO=yes"
set PHP_SDK_ROOT_PATH=%~dp0
set PHP_SDK_ROOT_PATH=%PHP_SDK_ROOT_PATH:~0,-1%

set PHP_SDK_RUN_FROM_ROOT=.\php-sdk
set CRT=vs16
set ARCH=x64
copy /Y ..\cmd\phpsdk_setshell.bat bin\phpsdk_setshell.bat
bin\phpsdk_setshell.bat vs16 x64 && bin\phpsdk_setvars.bat && bin\phpsdk_dumpenv.bat && bin\phpsdk_buildtree.bat phpdev && cd php-8.0.7 && IF NOT EXIST config.nice (..\..\..\..\bin\phpsdk_deps -u) && IF NOT EXIST "..\deps\include\uv" (
  cd .. && curl -L https://github.com/symplely/libuv/releases/download/libuv-v1.41.1-windows/libuv-v1.41.1.zip --output libuv-v1.41.1.zip && unzip -xoq libuv-v1.41.1.zip && copy /Y libuv-v1.41.1\bin\* deps\bin\ && copy /Y libuv-v1.41.1\include\* deps\include\ && mkdir deps\include\uv && copy /Y libuv-v1.41.1\include\uv\* deps\include\uv\ && copy /Y libuv-v1.41.1\lib\* deps\lib\ && del libuv-v1.41.1.zip && rmdir /S /Q libuv-v1.41.1 && copy /Y "C:\Program Files (x86)\Windows Kits\10\Lib\10.0.19041.0\um\x64\UserEnv.Lib" deps\lib\ && copy /Y "C:\Program Files (x86)\Windows Kits\10\Include\10.0.19041.0\um\UserEnv.h" deps\include\ && cd php-8.0.7 && buildconf --add-modules-dir=..\pecl\ && configure --enable-cli --with-uv --enable-sockets && nmake snap && cd ..\..\..\..\..
) else (
  buildconf --force --add-modules-dir=..\pecl\ && configure --enable-cli --with-uv --enable-sockets && nmake snap && cd ..\..\..\..\..
)
