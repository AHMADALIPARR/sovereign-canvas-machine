#!/usr/bin/env php
<?php
/**
 * Copyright (C) 2026 AHMAD ALI PARR
 * Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.
 *
 * Unix-domain socket ingress. One request → one pipeline decision.
 * Does not start an agent loop. Does not interpolate untrusted bytes into a shell.
 */

declare(strict_types=1);

const MAX_REQUEST = 65536;
const MAX_CANVAS  = 4096;
const MAX_GGUF_NAME = 128;

$root = getenv('SCM_ROOT') ?: realpath(dirname(__DIR__));
if ($root === false || !is_dir($root)) {
    fwrite(STDERR, "DENY:scm_root\n");
    exit(2);
}
$root = rtrim($root, '/');
putenv("SCM_ROOT=$root");

$sockPath = getenv('SCM_SOCK') ?: '';
if ($sockPath === '') {
    // Prefer $SCM_ROOT/run when the filesystem allows Unix sockets there;
    // many sandboxed trees only allow AF_UNIX under /tmp.
    $preferred = $root . '/run/scm.sock';
    $runDir = dirname($preferred);
    if (!is_dir($runDir)) {
        @mkdir($runDir, 0700, true);
    }
    $probe = @stream_socket_server('unix://' . $preferred, $pe, $ps);
    if ($probe !== false) {
        fclose($probe);
        @unlink($preferred);
        $sockPath = $preferred;
    } else {
        $sockPath = '/tmp/scm-' . getmyuid() . '.sock';
    }
}
$runDir   = dirname($sockPath);
$modelsDir = $root . '/models';
$ledgerEnv = getenv('SCM_LEDGER');

if (!is_dir($runDir) && !mkdir($runDir, 0700, true) && $runDir !== '/tmp') {
    fwrite(STDERR, "DENY:run_dir\n");
    exit(2);
}
if (!is_dir($modelsDir) && !mkdir($modelsDir, 0750, true)) {
    fwrite(STDERR, "DENY:models_dir\n");
    exit(2);
}

if (file_exists($sockPath)) {
    @unlink($sockPath);
}

$server = stream_socket_server("unix://$sockPath", $errno, $errstr);
if ($server === false) {
    fwrite(STDERR, "DENY:bind:$errstr\n");
    exit(2);
}
chmod($sockPath, 0600);
fwrite(STDERR, "SCM ingress listening on $sockPath\n");

while ($conn = @stream_socket_accept($server, -1)) {
    try {
        handle_connection($conn, $root, $modelsDir);
    } catch (Throwable $e) {
        @fwrite($conn, "REJECT: INGRESS:internal\n");
    }
    fclose($conn);
}

function handle_connection($conn, string $root, string $modelsDir): void
{
    stream_set_timeout($conn, 30);
    $raw = read_request($conn);
    if ($raw === null) {
        fwrite($conn, "REJECT: INGRESS:empty\n");
        return;
    }
    if (strlen($raw) > MAX_REQUEST) {
        fwrite($conn, "REJECT: INGRESS:too_large\n");
        return;
    }

    $trimmed = ltrim($raw);
    if ($trimmed !== '' && ($trimmed[0] === '{' || $trimmed[0] === '[')) {
        $resp = handle_json($raw, $root, $modelsDir);
    } else {
        $resp = handle_raw_canvas($raw, $root);
    }
    fwrite($conn, $resp);
}

function read_request($conn): ?string
{
    $buf = '';
    while (!feof($conn)) {
        $chunk = fread($conn, 8192);
        if ($chunk === false || $chunk === '') {
            break;
        }
        $buf .= $chunk;
        if (strlen($buf) > MAX_REQUEST) {
            return $buf;
        }
        if (str_ends_with(rtrim($buf), "\n.\n") || str_ends_with(rtrim($buf), "\n.")) {
            $buf = preg_replace("/\n\.\s*$/", "\n", $buf) ?? $buf;
            break;
        }
        if ($buf !== '' && $buf[0] === '{') {
            $dec = json_decode($buf, true);
            if (is_array($dec)) {
                break;
            }
        }
    }
    return $buf === '' ? null : $buf;
}

function handle_raw_canvas(string $text, string $root): string
{
    $text = normalize_canvas($text);
    if ($text === null) {
        return "REJECT: INGRESS:bad_canvas\n";
    }
    return run_pipeline($text, $root, false);
}

function handle_json(string $raw, string $root, string $modelsDir): string
{
    $msg = json_decode($raw, true);
    if (!is_array($msg)) {
        return "REJECT: INGRESS:bad_json\n";
    }
    $op = $msg['op'] ?? 'propose';
    $replyJson = (($msg['reply'] ?? '') === 'json');

    switch ($op) {
        case 'ping':
            return format_reply($replyJson, true, "PONG\n", []);
        case 'list_models':
            $list = list_gguf($modelsDir);
            if ($replyJson) {
                return json_encode(['ok' => true, 'models' => $list], JSON_UNESCAPED_SLASHES) . "\n";
            }
            return $list === [] ? "MODELS:\n" : ("MODELS:\n" . implode("\n", $list) . "\n");
        case 'register_gguf':
            return register_gguf($msg, $modelsDir, $replyJson);
        case 'generate':
            return generate_from_gguf($msg, $root, $modelsDir, $replyJson);
        case 'propose':
            return propose_from_json($msg, $root, $replyJson);
        default:
            return format_reply($replyJson, false, "REJECT: INGRESS:unknown_op\n", []);
    }
}

function propose_from_json(array $msg, string $root, bool $replyJson): string
{
    $format = $msg['format'] ?? 'canvas';
    if ($format !== 'canvas') {
        return format_reply($replyJson, false, "REJECT: INGRESS:bad_format\n", []);
    }
    if (isset($msg['path'])) {
        $path = (string)$msg['path'];
        if (!safe_rel_path($path)) {
            return format_reply($replyJson, false, "REJECT: INGRESS:bad_path\n", []);
        }
        $full = $root . '/' . $path;
        if (!is_file($full) || !is_readable($full)) {
            return format_reply($replyJson, false, "REJECT: INGRESS:path_missing\n", []);
        }
        $body = file_get_contents($full);
        if ($body === false) {
            return format_reply($replyJson, false, "REJECT: INGRESS:path_read\n", []);
        }
    } else {
        $body = (string)($msg['body'] ?? '');
    }
    $text = normalize_canvas($body);
    if ($text === null) {
        return format_reply($replyJson, false, "REJECT: INGRESS:bad_canvas\n", []);
    }
    return run_pipeline($text, $root, $replyJson);
}

function normalize_canvas(string $text): ?string
{
    $text = str_replace("\r\n", "\n", $text);
    $text = str_replace("\r", "\n", $text);
    $text = trim($text) . "\n";
    if (strlen($text) > MAX_CANVAS) {
        return null;
    }
    if (!str_starts_with($text, 'SCM-CANVAS/1.0')) {
        return null;
    }
    if (!str_contains($text, "\nEND\n") && !str_ends_with(rtrim($text), "\nEND")) {
        return null;
    }
    return $text;
}

function safe_rel_path(string $path): bool
{
    if ($path === '' || $path[0] === '/' || str_contains($path, "\0")) {
        return false;
    }
    if (str_contains($path, '..')) {
        return false;
    }
    return (bool)preg_match('#^[A-Za-z0-9._/-]+$#', $path);
}

function run_pipeline(string $text, string $root, bool $replyJson): string
{
    $supervisor = $root . '/perl/scm_supervisor.pl';
    if (!is_file($supervisor)) {
        return format_reply($replyJson, false, "REJECT: INGRESS:no_supervisor\n", []);
    }
    $descriptors = [
        0 => ['pipe', 'r'],
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];
    $env = $_ENV + [
        'SCM_ROOT' => $root,
        'SCM_TRACE' => '1',
        'PATH' => getenv('PATH') ?: '/usr/local/bin:/usr/bin:/bin',
    ];
    if (getenv('SCM_LEDGER')) {
        $env['SCM_LEDGER'] = getenv('SCM_LEDGER');
    }
    $proc = proc_open(
        ['perl', $supervisor],
        $descriptors,
        $pipes,
        $root,
        $env
    );
    if (!is_resource($proc)) {
        return format_reply($replyJson, false, "REJECT: INGRESS:exec\n", []);
    }
    fwrite($pipes[0], $text);
    fclose($pipes[0]);
    $stdout = stream_get_contents($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    $code = proc_close($proc);
    $line = $stdout === false ? "REJECT: INGRESS:no_output\n" : $stdout;
    if ($line !== '' && $line[-1] !== "\n") {
        $line .= "\n";
    }
    $trace = [];
    if (is_string($stderr) && $stderr !== '') {
        foreach (explode("\n", trim($stderr)) as $t) {
            if ($t !== '') {
                $trace[] = $t;
            }
        }
    }
    $ok = ($code === 0) && str_starts_with($line, 'ACCEPT:');
    return format_reply($replyJson, $ok, $line, $trace);
}

function format_reply(bool $asJson, bool $ok, string $line, array $trace): string
{
    if (!$asJson) {
        return $line;
    }
    return json_encode([
        'ok'    => $ok,
        'line'  => rtrim($line),
        'trace' => $trace,
    ], JSON_UNESCAPED_SLASHES) . "\n";
}

function list_gguf(string $modelsDir): array
{
    $out = [];
    foreach (scandir($modelsDir) ?: [] as $f) {
        if (preg_match('/^[A-Za-z0-9._-]{1,128}\.gguf$/', $f) && is_file($modelsDir . '/' . $f)) {
            $out[] = $f;
        }
    }
    sort($out);
    return $out;
}

function register_gguf(array $msg, string $modelsDir, bool $replyJson): string
{
    $name = (string)($msg['name'] ?? '');
    $source = (string)($msg['source'] ?? '');
    if (!preg_match('/^[A-Za-z0-9._-]{1,128}\.gguf$/', $name)) {
        return format_reply($replyJson, false, "REJECT: GGUF:bad_name\n", []);
    }
    if ($source === '' || $source[0] !== '/' || str_contains($source, "\0")) {
        return format_reply($replyJson, false, "REJECT: GGUF:bad_source\n", []);
    }
    $real = realpath($source);
    if ($real === false || !is_file($real) || !is_readable($real)) {
        return format_reply($replyJson, false, "REJECT: GGUF:source_missing\n", []);
    }
    $allowed = getenv('SCM_GGUF_ALLOW_PREFIX');
    if (is_string($allowed) && $allowed !== '') {
        $prefix = realpath($allowed);
        if ($prefix === false || !str_starts_with($real, rtrim($prefix, '/') . '/')) {
            return format_reply($replyJson, false, "REJECT: GGUF:source_denied\n", []);
        }
    }
    $size = filesize($real);
    $max = (int)(getenv('SCM_GGUF_MAX_BYTES') ?: (8 * 1024 * 1024 * 1024));
    if ($size === false || $size < 4 || $size > $max) {
        return format_reply($replyJson, false, "REJECT: GGUF:size\n", []);
    }
    $fh = fopen($real, 'rb');
    if ($fh === false) {
        return format_reply($replyJson, false, "REJECT: GGUF:source_read\n", []);
    }
    $magic = fread($fh, 4);
    fclose($fh);
    if ($magic !== 'GGUF') {
        return format_reply($replyJson, false, "REJECT: GGUF:not_gguf\n", []);
    }
    $dest = $modelsDir . '/' . $name;
    if (file_exists($dest)) {
        return format_reply($replyJson, false, "REJECT: GGUF:exists\n", []);
    }
    if (@link($real, $dest) !== true) {
        if (!@copy($real, $dest)) {
            return format_reply($replyJson, false, "REJECT: GGUF:copy_failed\n", []);
        }
    }
    chmod($dest, 0640);
    return format_reply($replyJson, true, "REGISTERED: $name\n", []);
}

function generate_from_gguf(array $msg, string $root, string $modelsDir, bool $replyJson): string
{
    $name = (string)($msg['model'] ?? '');
    if (!preg_match('/^[A-Za-z0-9._-]{1,128}\.gguf$/', $name)) {
        return format_reply($replyJson, false, "REJECT: GGUF:bad_name\n", []);
    }
    $modelPath = $modelsDir . '/' . $name;
    if (!is_file($modelPath)) {
        return format_reply($replyJson, false, "REJECT: GGUF:not_registered\n", []);
    }
    $llama = getenv('SCM_LLAMA_BIN') ?: '';
    if ($llama === '') {
        foreach (['/usr/local/bin/llama-cli', '/usr/bin/llama-cli'] as $cand) {
            if (is_executable($cand)) { $llama = $cand; break; }
        }
    }
    if ($llama === '' || !is_executable($llama)) {
        return format_reply($replyJson, false, "REJECT: GGUF:no_llama\n", []);
    }
    $sysPrompt = $root . '/prompting/system_prompt.txt';
    if (!is_readable($sysPrompt)) {
        return format_reply($replyJson, false, "REJECT: GGUF:no_system_prompt\n", []);
    }
    $system = file_get_contents($sysPrompt);
    if ($system === false) {
        return format_reply($replyJson, false, "REJECT: GGUF:no_system_prompt\n", []);
    }
    $extra = trim((string)($msg['prompt'] ?? ''));
    if (strlen($extra) > 512) {
        return format_reply($replyJson, false, "REJECT: GGUF:prompt_too_long\n", []);
    }
    if (preg_match('/tool_calls|<tool|function_call|"tools"\s*:/i', $extra)) {
        return format_reply($replyJson, false, "REJECT: GGUF:tool_syntax\n", []);
    }
    $user = "Emit one SCM-CANVAS/1.0 record and stop.\n";
    if ($extra !== '') {
        $user .= $extra . "\n";
    }
    $tmpDir = sys_get_temp_dir() . '/scm-gguf-' . getmypid() . '-' . bin2hex(random_bytes(4));
    if (!mkdir($tmpDir, 0700)) {
        return format_reply($replyJson, false, "REJECT: GGUF:tmpdir\n", []);
    }
    $outFile = $tmpDir . '/out.txt';
    $cmd = [
        $llama,
        '-m', $modelPath,
        '--temp', '0',
        '-n', '256',
        '-c', '2048',
        '--no-display-prompt',
        '-p', $system . "\n\n" . $user,
    ];
    $descriptors = [
        0 => ['file', '/dev/null', 'r'],
        1 => ['file', $outFile, 'w'],
        2 => ['pipe', 'w'],
    ];
    $proc = proc_open($cmd, $descriptors, $pipes, $tmpDir, [
        'PATH' => '/usr/bin:/bin',
        'HOME' => $tmpDir,
    ]);
    if (!is_resource($proc)) {
        @unlink($outFile);
        @rmdir($tmpDir);
        return format_reply($replyJson, false, "REJECT: GGUF:exec\n", []);
    }
    $err = stream_get_contents($pipes[2]);
    fclose($pipes[2]);
    $code = proc_close($proc);
    $output = is_file($outFile) ? (string)file_get_contents($outFile) : '';
    @unlink($outFile);
    @rmdir($tmpDir);
    if ($code !== 0 && $output === '') {
        return format_reply($replyJson, false, "REJECT: GGUF:inference_failed\n", []);
    }
    if (preg_match('/tool_calls|<tool|function_call|"tools"\s*:/i', $output)) {
        return format_reply($replyJson, false, "REJECT: GGUF:tool_syntax\n", []);
    }
    $canvas = extract_canvas($output);
    if ($canvas === null) {
        return format_reply($replyJson, false, "REJECT: GGUF:no_canvas\n", []);
    }
    return run_pipeline($canvas, $root, $replyJson);
}

function extract_canvas(string $output): ?string
{
    if (!preg_match('/SCM-CANVAS\/1\.0\n.*?\nEND\s*(?:\n|$)/s', $output, $m)) {
        return null;
    }
    return normalize_canvas($m[0]);
}
