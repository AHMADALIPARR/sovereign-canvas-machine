#!/usr/bin/env php
<?php
/**
 * Copyright (C) 2026 AHMAD ALI PARR
 * Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.
 *
 * Smoke tests for the Unix-domain socket ingress.
 */

declare(strict_types=1);

$root = realpath(dirname(__DIR__));
if ($root === false) {
    fwrite(STDERR, "no root\n");
    exit(2);
}
putenv("SCM_ROOT=$root");
$sock = '/tmp/scm-test-' . getmypid() . '.sock';
putenv("SCM_SOCK=$sock");
@unlink($sock);

$serverCmd = ['php', $root . '/ingress/server.php'];
$descriptors = [
    0 => ['file', '/dev/null', 'r'],
    1 => ['file', '/dev/null', 'w'],
    2 => ['pipe', 'w'],
];
$proc = proc_open($serverCmd, $descriptors, $pipes, $root, [
    'SCM_ROOT' => $root,
    'SCM_SOCK' => $sock,
]);
if (!is_resource($proc)) {
    fwrite(STDERR, "failed to start server\n");
    exit(2);
}

$deadline = microtime(true) + 5.0;
while (!file_exists($sock) && microtime(true) < $deadline) {
    usleep(50000);
}
if (!file_exists($sock)) {
    fwrite(STDERR, "socket not created\n");
    proc_terminate($proc);
    exit(2);
}

function client(string $root, string $sock, string $payload): array
{
    $fp = stream_socket_client("unix://$sock", $errno, $errstr, 5);
    if ($fp === false) {
        return [2, "connect failed: $errstr"];
    }
    fwrite($fp, $payload);
    stream_socket_shutdown($fp, STREAM_SHUT_WR);
    $resp = stream_get_contents($fp);
    fclose($fp);
    return [0, $resp === false ? '' : $resp];
}

$failed = 0;
function check(string $name, bool $cond, string $detail = ''): void
{
    global $failed;
    if ($cond) {
        echo "ok - $name\n";
    } else {
        echo "not ok - $name" . ($detail !== '' ? " # $detail" : "") . "\n";
        $failed++;
    }
}

// ping
[, $r] = client($root, $sock, json_encode(['op' => 'ping']));
check('ping', str_starts_with($r, 'PONG'));

// JSON propose via path
[, $r] = client($root, $sock, json_encode([
    'op' => 'propose',
    'format' => 'canvas',
    'path' => 'fixtures/braid_valid.txt',
]));
check('propose path accept', str_starts_with($r, 'ACCEPT: AUTHORIZED'), trim($r));

// path traversal denied
[, $r] = client($root, $sock, json_encode([
    'op' => 'propose',
    'format' => 'canvas',
    'path' => '../etc/passwd',
]));
check('path traversal denied', str_contains($r, 'REJECT: INGRESS:bad_path'), trim($r));

// absolute path denied
[, $r] = client($root, $sock, json_encode([
    'op' => 'propose',
    'format' => 'canvas',
    'path' => '/etc/passwd',
]));
check('absolute path denied', str_contains($r, 'REJECT: INGRESS:bad_path'), trim($r));

// raw canvas
$canvas = file_get_contents($root . '/fixtures/braid_relation.txt');
[, $r] = client($root, $sock, $canvas);
check('raw canvas accept', str_starts_with($r, 'ACCEPT: AUTHORIZED'), trim($r));

// reject fixture
$bad = file_get_contents($root . '/fixtures/braid_unauthorized.txt');
[, $r] = client($root, $sock, $bad);
check('unauthorized rejected', str_starts_with($r, 'REJECT:'), trim($r));

// generate without llama / without model
[, $r] = client($root, $sock, json_encode([
    'op' => 'generate',
    'model' => 'missing.gguf',
]));
check('generate missing model', str_contains($r, 'REJECT: GGUF:'), trim($r));

// register rejects non-gguf
$tmp = tempnam(sys_get_temp_dir(), 'scm');
file_put_contents($tmp, 'NOTGGUF');
[, $r] = client($root, $sock, json_encode([
    'op' => 'register_gguf',
    'name' => 'fake.gguf',
    'source' => $tmp,
]));
@unlink($tmp);
check('register non-gguf', str_contains($r, 'REJECT: GGUF:not_gguf'), trim($r));

// register valid magic
$tmp = tempnam(sys_get_temp_dir(), 'scm') . '.gguf';
file_put_contents($tmp, 'GGUF' . str_repeat("\0", 60));
@unlink($root . '/models/test-mini.gguf');
[, $r] = client($root, $sock, json_encode([
    'op' => 'register_gguf',
    'name' => 'test-mini.gguf',
    'source' => $tmp,
]));
@unlink($tmp);
check('register mini gguf', str_starts_with($r, 'REGISTERED:'), trim($r));
check('model file present', is_file($root . '/models/test-mini.gguf'));

// list models
[, $r] = client($root, $sock, json_encode(['op' => 'list_models']));
check('list models', str_contains($r, 'test-mini.gguf'), trim($r));

// generate with registered model but no llama binary → fail closed
[, $r] = client($root, $sock, json_encode([
    'op' => 'generate',
    'model' => 'test-mini.gguf',
]));
check('generate no llama', str_contains($r, 'REJECT: GGUF:no_llama'), trim($r));

// JSON reply wrapper
[, $r] = client($root, $sock, json_encode([
    'op' => 'propose',
    'format' => 'canvas',
    'path' => 'fixtures/braid_valid.txt',
    'reply' => 'json',
]));
$j = json_decode($r, true);
check('json reply ok', is_array($j) && ($j['ok'] ?? false) === true, trim($r));

@unlink($root . '/models/test-mini.gguf');
proc_terminate($proc);
proc_close($proc);
@unlink($sock);

if ($failed > 0) {
    echo "# failed $failed\n";
    exit(1);
}
echo "# all ingress checks passed\n";
exit(0);
