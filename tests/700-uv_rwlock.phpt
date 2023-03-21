--TEST--
Check for uv_rwlock
--INI--
track_errors=0
--FILE--
<?php
$lock = uv_rwlock_init();

uv_rwlock_rdlock($lock);
if (uv_rwlock_tryrdlock($lock)) {
    echo "OK" . PHP_EOL;
} else {
    echo "FAILED" . PHP_EOL;
}
uv_rwlock_rdunlock($lock);
if (uv_rwlock_tryrdlock($lock)) {
    echo "OK" . PHP_EOL;
} else {
    echo "FAILED" . PHP_EOL;
}

uv_rwlock_rdunlock($lock);
--EXPECTF--
OK
OK

Notice: %S
