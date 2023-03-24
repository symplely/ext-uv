--TEST--
Check for uv_tty
--SKIPIF--
<?php
if (function_exists("posix_isatty") && defined("STDIN") && !posix_isatty(STDIN)) {
    die("skip test requiring a tty\n");
}
?>
--FILE--
<?php
uv_fs_open(uv_default_loop(), ('\\' === \DIRECTORY_SEPARATOR) ? '\\\\?\\CON' : '/dev/tty', UV::O_RDONLY, 0, function($r) {
    $tty = uv_tty_init(uv_default_loop(), $r, 1);
    $error = uv_tty_get_winsize($tty, $width, $height);
    if ($width >= 0) {
        echo "OK\n";
    }
    if ($height >= 0) {
        echo "OK\n";
    } elseif ('\\' === \DIRECTORY_SEPARATOR) {
        echo $height. ' ' .uv_strerror($error);
    }

echo 'error: ' .$error. ' - height is: '. $height . ' - uv error: '. uv_strerror($error);
});

uv_run();
--EXPECTF--
OK
OK
