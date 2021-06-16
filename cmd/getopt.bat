@echo off
:parse
if "%~1" == "" goto endparse
if "%~1" == "--php" set PHP_VER=%2
if "%~1" == "--uv" set LIBUV_VER=%2
if "%~1" == "--shared" (
  if EXIST config.w32.bak ( ren config.w32 config.w32.shared && ren config.w32.bak config.w32)
  set UV_SHARED=--with-uv=shared
  ren config.w32 config.w32.bak
  ren config.w32.shared config.w32
)

shift
goto parse
:endparse
if not defined LIBUV_VER (
  if EXIST "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community" (
    set LIBUV_VER=1.41.0
  ) else (
    set LIBUV_VER=1.41.1
  )
)
