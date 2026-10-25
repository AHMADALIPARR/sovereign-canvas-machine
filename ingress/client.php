#!/usr/bin/env php
<?php
/**
 * Copyright (C) 2026 AHMAD ALI PARR
 * Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.
 *
 * Client for the Unix-domain socket ingress.
 *
 *   php ingress/client.php --raw                 < canvas.txt
 *   php ingress/client.php --json '{"op":"ping"}'
 *   php ingress/client.php --file fixtures/braid_valid.txt
 */

declare(strict_types=1);

$root = getenv('SCM_ROOT') ?: realpath(dirname(__DIR__));
if ($root === false) {
    fwrite(STDERR, "DENY:scm_root\n");
    exit(2);
}
$root = rtrim($root, '/');
$sockPath = getenv('SCM_SOCK') ?: ($root . '/run/scm.sock');

$mode = null;
$payload = null;
$args = array_slice($argv, 1);
for ($i = 0; $i < count($args); $i++) {
    $a = $args[$i];
    if ($a === '--raw') {
        $mode = 'raw';
        $payload = stream_get_contents(STDIN);
    } elseif ($a === '--json' && isset($args[$i + 1])) {
        $mode = 'json';
        $payload = $args[++$i];
    } elseif ($a === '--file' && isset($args[$i + 1])) {
        $mode = 'json';
        $path = $args[++$i];
        $payload = json_encode([
            'op' => 'propose',
            'format' => 'canvas',
            'path' => $path,
            'reply' => 'json',
        ], JSON_UNESCAPED_SLASHES);
    } elseif ($a === '--sock' && isset($args[$i + 1])) {
        $sockPath = $args[++$i];
    } elseif ($a === '--help' || $a === '-h') {
        fwrite(STDOUT, "Usage: client.php --raw | --json '...' | --file rel/path\n");
        exit(0);
    } else {
        fwrite(STDERR, "REJECT: CLIENT:bad_arg\n");
        exit(2);
    }
}

if ($mode === null || $payload === null || $payload === false || $payload === '') {
    fwrite(STDERR, "REJECT: CLIENT:empty\n");
    exit(2);
}

if (!file_exists($sockPath)) {
    fwrite(STDERR, "REJECT: CLIENT:no_socket ($sockPath)\n");
    exit(2);
}

$fp = @stream_socket_client("unix://$sockPath", $errno, $errstr, 5);
if ($fp === false) {
    fwrite(STDERR, "REJECT: CLIENT:connect:$errstr\n");
    exit(2);
}

fwrite($fp, $payload);
if ($mode === 'raw' && !str_ends_with($payload, "\n")) {
    fwrite($fp, "\n");
}
// Signal end for raw mode when server waits for close.
stream_socket_shutdown($fp, STREAM_SHUT_WR);

$resp = stream_get_contents($fp);
fclose($fp);
fwrite(STDOUT, $resp === false ? '' : $resp);

$ok = is_string($resp) && (
    str_starts_with($resp, 'ACCEPT:') ||
    str_starts_with($resp, 'PONG') ||
    str_starts_with($resp, 'REGISTERED:') ||
    str_starts_with($resp, 'MODELS:') ||
    (str_contains($resp, '"ok":true'))
);
exit($ok ? 0 : 1);
