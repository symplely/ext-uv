@echo off
call cmd\getopt.bat %*
IF EXIST php-sdk\phpdev\vs16\x64\php-%PHP_VER%\x64\Release\php-%PHP_VER%\php.exe (
  cd php-sdk\phpdev\vs16\x64\php-%PHP_VER%\x64\Release\php-%PHP_VER%
  IF EXIST ..\pecl-%PHP_VER%\php_uv.dll (
    copy /Y ..\pecl-%PHP_VER%\php_uv.dll ext\
    copy /Y php.ini-production php.ini
    echo extension=uv >> php.ini
  )

  php -m
  php ..\..\..\run-tests.php --offline --show-diff --set-timeout 120 ..\..\..\..\pecl\uv\tests
  dir
  dir ..
)
