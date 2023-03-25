@echo off
if not defined PHP_VER set PHP_VER=8.2.4

if "%PHP_VER%" == "7.4.33" (
    set CRT=vc15
) else (
    set CRT=vs16
)

call cmd\getopt.bat %*
dir php-sdk\phpdev\%CRT%\x64\php-%PHP_VER%\x64\Release%PHP_TS%
dir php-sdk\phpdev\%CRT%\x64\php-%PHP_VER%\x64\Release%PHP_TS%\php-%PHP_VER%
dir php-sdk\phpdev\%CRT%\x64\php-%PHP_VER%\x64\Release%PHP_TS%\pecl\uv
dir php-sdk\phpdev\%CRT%\x64\php-%PHP_VER%\x64\Release%PHP_TS%\pecl-%PHP_VER%
cd php-sdk\phpdev\%CRT%\x64\php-%PHP_VER%\x64\Release%PHP_TS%\php-%PHP_VER%
IF EXIST php.exe (
  IF EXIST ..\pecl-%PHP_VER%\php_uv.dll (
    copy /Y ..\pecl-%PHP_VER%\php_uv.dll ext\
    IF NOT EXIST php.ini (
      rem copy /Y php.ini-production php.ini
      echo extension=uv >> php.ini
      echo extension=php_uv >> php.ini
      echo extension=php_uv.dll >> php.ini
    )
  )

dir ext
copy /Y uv.dll libuv.dll
php ..\..\..\run-tests.php --offline --show-diff --set-timeout 240 ..\..\..\..\pecl\uv\tests
)
