--TEST--
Check for uv_queue_work
--SKIPIF--
<?php
ob_start();
phpinfo();
$data = ob_get_clean();
if (!preg_match("/Thread Safety.+?enabled/", $data)) {
  echo "skip not implemented for PHP 8+, Windows after callback not called, and shows segfault";
}
--FILE--
<?php
$loop = uv_default_loop();

$a = function() {
    echo "[queue]";
};

$b = function() {
    echo "[finished]";
};
$queue = uv_queue_work($loop, $a, $b);
uv_run();
--EXPECT--
[queue][finished]
