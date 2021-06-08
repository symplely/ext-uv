@echo off
IF EXIST php-sdk\phpdev\vs16\x64\php-8.0.7\x64\Release\php-8.0.7\php.exe (
  cd php-sdk\phpdev\vs16\x64\php-8.0.7\x64\Release\php-8.0.7
  php ..\..\..\run-tests.php --offline --show-diff --set-timeout 120 ..\..\..\..\pecl\uv\tests
  dir
  dir ..
)
