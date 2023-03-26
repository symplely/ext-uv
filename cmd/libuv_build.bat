@echo off

    curl -L https://github.com/libuv/libuv/archive/refs/tags/v%LIBUV_VER%.zip --output libuv-%LIBUV_VER%.zip
    unzip -xoq libuv-%LIBUV_VER%.zip
    cd libuv-%LIBUV_VER%
    cmake . -DBUILD_TESTING=OFF
    cmake --build . --config Release
    mkdir ..\deps\include\uv
    copy /Y include\uv\* ..\deps\include\uv\
    copy /Y include\* ..\deps\include\
    copy /Y Release\uv_a.lib ..\deps\lib\
    copy /Y Release\uv.lib ..\deps\lib\
    copy /Y Release\uv.lib ..\deps\lib\libuv.lib
    copy /Y Release\uv.exp ..\deps\lib\
    copy /Y Release\uv.dll ..\deps\bin\
    copy /Y Release\uv.dll ..\deps\bin\libuv.dll
    dir Release
    cd ..

del libuv-%LIBUV_VER%.zip
rmdir /S /Q libuv-%LIBUV_VER%
