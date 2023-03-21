@echo off
if EXIST "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise" (
	curl -L https://github.com/symplely/libuv/releases/download/libuv-v%LIBUV_VER%-windows/libuv-v%LIBUV_VER%.zip --output libuv-%LIBUV_VER%.zip
	unzip -xoq libuv-%LIBUV_VER%.zip
	copy /Y libuv-%LIBUV_VER%\bin\* deps\bin\
	copy /Y libuv-%LIBUV_VER%\include\* deps\include\
	mkdir deps\include\uv
	copy /Y libuv-%LIBUV_VER%\include\uv\* deps\include\uv\
	copy /Y libuv-%LIBUV_VER%\lib\* deps\lib\
) else (
	curl -L https://github.com/libuv/libuv/archive/refs/tags/v%LIBUV_VER%.zip --output libuv-%LIBUV_VER%.zip
	unzip -xoq libuv-%LIBUV_VER%.zip
	cd libuv-%LIBUV_VER%
	cmake .
	msbuild INSTALL.vcxproj /p:Configuration=Release
	mkdir ..\deps\include\uv
	copy /Y include\uv\* ..\deps\include\uv\
	copy /Y include\* ..\deps\include\
	copy /Y Release\uv_a.lib ..\deps\lib\
	copy /Y Release\uv.lib ..\deps\lib\
	copy /Y Release\uv.exp ..\deps\lib\
	copy /Y Release\uv.dll ..\deps\bin\
	cd ..
)

del libuv-%LIBUV_VER%.zip
rmdir /S /Q libuv-%LIBUV_VER%
copy /Y "C:\Program Files (x86)\Windows Kits\10\Lib\10.0.19041.0\um\x64\UserEnv.Lib" deps\lib\
copy /Y "C:\Program Files (x86)\Windows Kits\10\Include\10.0.19041.0\um\UserEnv.h" deps\include\
copy /Y C:\Windows\SysWOW64\userenv.dll deps\bin\
