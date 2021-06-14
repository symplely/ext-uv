@echo off
:parse
if "%~1" == "" goto endparse
if "%~1" == "--php" set PHP_VER=%2
if "%~1" == "--uv" set LIBUV_VER=%2
if "%~1" == "--shared" set UV_SHARED=--with-uv=shared
shift
goto parse
:endparse
if not defined PHP_VER set PHP_VER=8.0.7
if not defined LIBUV_VER set LIBUV_VER=v1.41.1
if not defined UV_SHARED set UV_SHARED=--with-uv
