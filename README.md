# ext-uv

[![Apple macOS](https://github.com/symplely/ext-uv/actions/workflows/Apple-macOS.yml/badge.svg)](https://github.com/symplely/ext-uv/actions/workflows/Apple-macOS.yml)
[![CentOS 7](https://github.com/symplely/ext-uv/actions/workflows/CentOS-7.yml/badge.svg)](https://github.com/symplely/ext-uv/actions/workflows/CentOS-7.yml)
[![CentOS stream](https://github.com/symplely/ext-uv/actions/workflows/Centos-stream.yml/badge.svg)](https://github.com/symplely/ext-uv/actions/workflows/Centos-stream.yml)
[![Ubuntu](https://github.com/symplely/ext-uv/actions/workflows/Ubuntu.yml/badge.svg)](https://github.com/symplely/ext-uv/actions/workflows/Ubuntu.yml)
[![Windows PHP 7.4](https://github.com/symplely/ext-uv/actions/workflows/Windows-7.4.yml/badge.svg)](https://github.com/symplely/ext-uv/actions/workflows/Windows-7.4.yml)
[![Windows PHP 8+](https://github.com/symplely/ext-uv/actions/workflows/Windows-8plus.yml/badge.svg)](https://github.com/symplely/ext-uv/actions/workflows/Windows-8plus.yml)

Interface to **libuv** for php.

## Compiling for Linux, macOS, and Windows

For **Apple macOS**

```bash
brew install libuv autoconf automake libtool pkg-config
```

For **Debian** like distributions, Ubuntu...

```bash
apt-get install libuv1-dev php-pear -y
```

The quickest way to get _ZTS_ PHP versions for **ubuntu** is by way of [shivammathur/php-builder](https://github.com/shivammathur/php-builder). This method installs all extensions, to disable do: `sudo phpdismod xdebug`.

```bash
curl -sSLO https://github.com/shivammathur/php-builder/releases/latest/download/install.sh
chmod a+x ./install.sh
# ./install.sh <php-version> <release|debug> <nts|zts>
./install.sh 8.2 debug zts
```

For **RedHat** like distributions, CentOS...

```bash
yum install libuv-devel php-pear -y
```

To build **libuv** `.so` library from source

```bash
git clone https://github.com/libuv/libuv.git
cd libuv
cmake . -DBUILD_TESTING=ON
cmake --build . --config Release
ls -lh
cp include/uv/* deps/include/uv
cp include/* deps/include/
cp Release/uv.la deps/lib
cp Release/uv.so deps/lib
```

To build **ext-uv** `.so`

```bash
# any branch except `master`, will contain more unfinished broken buggy development work
git clone --branch 0.3x https://github.com/symplely/ext-uv.git
cd ext-uv
phpize
./configure --with-uv=$(readlink -f `pwd`/libuv)
make
make install
echo "extension=uv.so" >> "$(php -r 'echo php_ini_loaded_file();')"
```

For **Windows** - needs Visual Studio 2019

```bat
git clone https://github.com/symplely/ext-uv.git
cd ext-uv
rem passing `--shared` results in uv.dll, php_uv.dll modules not loading correctly
.\cmd\compile_x64.bat --php 8.2.4 --ts
rem for testing
.\cmd\windows_run_test.bat --php 8.2.4 --ts
rem files in
dir php-sdk\phpdev\vs16\x64\php-8.2.4\x64\
```

## Binaries for PHP 7.4 - 8.2

- See [Releases](https://github.com/symplely/ext-uv/releases) page, for Windows, Linux - Debian/Redhat, Apple macOS - 10.15, 11, 12
- PHP 8+ versions for **Windows** are static builds, issues building `--shared`, results in a _shared_ module not loading correctly. PHP 7.4 for Windows can be built `static` or `shared` and correctly loads.

## Or bypass both and just use **libuv FFI** version [symplely/uv-ffi](https://github.com/symplely/uv-ffi)

## Examples

- see [examples](https://github.com/symplely/ext-uv/tree/master/examples) folder for usage.

```php
<?php
$tcp = uv_tcp_init();

uv_tcp_bind($tcp, uv_ip4_addr('0.0.0.0',8888));

uv_listen($tcp,100, function($server){
    $client = uv_tcp_init();
    uv_accept($server, $client);
    var_dump(uv_tcp_getsockname($server));

    uv_read_start($client, function($socket, $nread, $buffer){
        var_dump($buffer);
        uv_close($socket);
    });
});

$c = uv_tcp_init();
uv_tcp_connect($c, uv_ip4_addr('0.0.0.0',8888), function($stream, $stat){
    if ($stat == 0) {
        uv_write($stream,"Hello",function($stream, $stat){
            uv_close($stream);
        });
    }
});

uv_run();
```

### Original Author

- Shuhei Tanuma

## License

PHP License

## Documentation

Use your favorite **IDE** and pull in the provided [**stubs**](https://github.com/symplely/ext-uv/tree/master/stubs), most functions DocBlock give overview of usage.

For deeper usage understanding, see the online [book](https://nikhilm.github.io/uvbook/index.html) or [An Introduction to libuv](https://codeahoy.com/learn/libuv/toc/) for a full tutorial overview.

### Basic overview of **libuv**

## Design

**libuv** is cross-platform support library which was originally written for _**Node.js**_. It’s designed around the event-driven _asynchronous_ I/O model.

The library provides much more than a simple abstraction over different I/O polling mechanisms: `‘handles’` and `‘streams’` provide a high level abstraction for `sockets` and other entities; cross-platform **file I/O** and **threading** functionality is also provided, amongst other things.

## Handles and Requests

**libuv** provides users with 2 abstractions to work with, in combination with the event loop: handles and requests.

_**Handles**_ represent long-lived objects capable of performing certain operations while active. Some examples:

- A prepare handle gets its callback called once every loop iteration when active.
- A TCP server handle that gets its connection callback called every time there is a new connection.

_**Requests**_ represent (typically) short-lived operations. These operations can be performed over a handle: `uv_write` requests are used to write data on a handle; or standalone: `uv_getaddrinfo` requests don’t need a handle they run directly on the loop.

## The I/O loop

The I/O (or event) loop is the central part of **libuv**. It establishes the content for all I/O operations, and it’s meant to be tied to a **single thread**. One can run multiple event loops as long as each runs in a different thread. The **libuv** event loop (or any other API involving the loop or handles, for that matter) is not thread-safe except where stated otherwise.

The event loop follows the rather usual single threaded asynchronous I/O approach:

- all (network) I/O is performed on _non-blocking sockets_ which are polled using the best mechanism available on the given platform: _epoll_ on `Linux`, _kqueue_ on `OSX` and other BSDs, _event ports_ on `SunOS` and _IOCP_ on `Windows`.

- As part of a loop iteration the loop will block waiting for I/O activity on sockets which have been added to the poller and callbacks will be fired indicating socket conditions (_readable_, _writable_ hangup) so handles can _read_, _write_ or perform the desired I/O operation.

- Use a thread pool to make asynchronous file I/O operations possible, but network I/O is always performed in a single thread, each loop’s thread.

>Note: While the polling mechanism is different, **libuv** makes the execution model consistent across Unix systems and Windows.

![loop][iteration]

## File I/O

Unlike network I/O, there are no platform-specific file I/O primitives **libuv** could rely on, so the current approach is to run blocking file I/O operations in a thread pool.

For a thorough explanation of the cross-platform file I/O landscape, checkout this [post](https://blog.libtorrent.org/2012/10/asynchronous-disk-io/).

**libuv** currently uses a global thread pool on which all loops can queue work. 3 types of operations are currently run on this pool:

- File system operations
- DNS functions (`uv_getaddrinfo`)
- User specified code via `uv_queue_work()`

## Thread pool work scheduling

**libuv** provides a threadpool which can be used to run user code and get notified in the loop thread. This thread pool is internally used to run all file system operations, as well as `uv_getaddrinfo` requests.

Its default size is 4, but it can be changed at startup time (the absolute maximum is 1024).

The threadpool is global and shared across all event loops. When a particular function makes use of the threadpool (i.e. when using `uv_queue_work()`) **libuv** preallocates and initializes the maximum number of threads allowed. This causes a relatively minor memory overhead (~1MB for 128 threads) but increases the performance of threading at runtime.

>Note that even though a global thread pool which is shared across all events loops is used, the functions are not thread safe.

[iteration]: http://docs.libuv.org/en/v1.x/_images/loop_iteration.png
