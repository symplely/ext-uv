@echo off
:parse
if "%~1" == "" goto endparse
if "%~1" == "--php" set PHP_VER=%2
if "%~1" == "--uv" set LIBUV_VER=%2
if "%~1" == "--ts" set PHP_TS=_TS
if "%~1" == "--shared" set UV_SHARED=--with-uv=shared

shift
goto parse
:endparse
if not defined LIBUV_VER (
    set LIBUV_VER=1.44.2
)
