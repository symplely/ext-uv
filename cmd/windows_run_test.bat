@echo off
if not defined PHP_VER set PHP_VER=8.2.4

if "%PHP_VER%" == "7.4.33" (
    set CRT=vs15
) else (
    set CRT=vs16
)

call cmd\getopt.bat %*
IF EXIST php-sdk\phpdev\%CRT%\x64\php-%PHP_VER%\x64\Release\php-%PHP_VER%\php.exe (
  cd php-sdk\phpdev\%CRT%\x64\php-%PHP_VER%\x64\Release\php-%PHP_VER%
  IF EXIST ..\pecl-%PHP_VER%\php_uv.dll (
    copy /Y ..\pecl-%PHP_VER%\php_uv.dll ext\
    IF NOT EXIST php.ini (
      copy /Y php.ini-production php.ini
      echo extension=uv >> php.ini
    )
  )

  php -m
  php -v
  php ..\..\..\run-tests.php --offline --show-diff --set-timeout 120 ..\..\..\..\pecl\uv\tests
  dir php-sdk\phpdev\%CRT%\x64\php-%PHP_VER%\x64\Release
  dir php-sdk\phpdev\%CRT%\x64\php-%PHP_VER%\x64
)
