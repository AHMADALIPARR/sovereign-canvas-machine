#!/usr/bin/env php
<?php
/**
 * Copyright (C) 2026 AHMAD ALI PARR
 * Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.
 *
 * Read–Eval–Print loop for the Unix-socket ingress / pipeline.
 *
 *   php ingress/repl.php
 *   php ingress/repl.php --direct          # no socket; call supervisor only
 *   php ingress/repl.php --sock /path.sock
 *
 * Commands (leading colon optional):
 *   help | ?              this text
 *   ping                  health check
 *   models                list registered GGUFs
 *   file <relpath>        propose a fixture / canvas file
 *   propose               multi-line canvas until a line with only END
 *   generate [model]      GGUF generate (default: snapkitty-merged.Q4_K_M.gguf)
 *   register <name> <abs> register a local .gguf
 *   json <object>         send raw JSON op
 *   quit | exit | :q      leave
 *
 * Anything that starts with SCM-CANVAS/1.0 is treated as a multi-line propose
 * (read until END).
 */

declare(strict_types=1);

$root = getenv('SCM_ROOT') ?: realpath(dirname(__DIR__));
if ($root === false || !is_dir($root)) {
    fwrite(STDERR, "DENY:scm_root\n");
    exit(2);
}
$root = rtrim($root, '/');
putenv("SCM_ROOT=$root");

$direct = false;
$sockPath = getenv('SCM_SOCK') ?: '';
$args = array_slice($argv, 1);
for ($i = 0; $i < count($args); $i++) {
    if ($args[$i] === '--direct') {
        $direct = true;
    } elseif ($args[$i] === '--sock' && isset($args[$i + 1])) {
        $sockPath = $args[++$i];
    } elseif ($args[$i] === '--help' || $args[$i] === '-h') {
        fwrite(STDOUT, "Usage: repl.php [--direct] [--sock path]\n");
        exit(0);
    }
}

if ($sockPath === '') {
    $preferred = $root . '/run/scm.sock';
    $sockPath = is_file($preferred) || is_dir(dirname($preferred))
        ? $preferred
        : ('/tmp/scm-' . getmyuid() . '.sock');
    if (!file_exists($sockPath) && file_exists('/tmp/scm-' . getmyuid() . '.sock')) {
        $sockPath = '/tmp/scm-' . getmyuid() . '.sock';
    }
}

$defaultModel = 'snapkitty-merged.Q4_K_M.gguf';

print_banner($root, $sockPath, $direct);

while (true) {
    $line = read_line('scm> ');
    if ($line === null) {
        fwrite(STDOUT, "\n");
        break;
    }
    $line = rtrim($line, "\r\n");
    if ($line === '') {
        continue;
    }

    if (str_starts_with($line, 'SCM-CANVAS/1.0')) {
        $body = $line . "\n";
        while (true) {
            $more = read_line('... ');
            if ($more === null) {
                break 2;
            }
            $more = rtrim($more, "\r\n");
            $body .= $more . "\n";
            if ($more === 'END') {
                break;
            }
        }
        print_result(request_raw($body, $root, $sockPath, $direct));
        continue;
    }

    $trimmed = ltrim($line);
    if ($trimmed !== '' && $trimmed[0] === ':') {
        $trimmed = substr($trimmed, 1);
    }
    $parts = preg_split('/\s+/', $trimmed, 2);
    $cmd = strtolower($parts[0] ?? '');
    $rest = isset($parts[1]) ? trim($parts[1]) : '';

    switch ($cmd) {
        case 'help':
        case '?':
            print_help($defaultModel);
            break;
        case 'quit':
        case 'exit':
        case 'q':
            fwrite(STDOUT, "bye\n");
            exit(0);
        case 'ping':
            print_result(request_json(['op' => 'ping'], $root, $sockPath, $direct));
            break;
        case 'models':
            print_result(request_json(['op' => 'list_models'], $root, $sockPath, $direct));
            break;
        case 'file':
            if ($rest === '' || !safe_rel($rest)) {
                fwrite(STDOUT, "REJECT: REPL:bad_path\n");
                break;
            }
            print_result(request_json([
                'op' => 'propose',
                'format' => 'canvas',
                'path' => $rest,
            ], $root, $sockPath, $direct));
            break;
        case 'propose':
            fwrite(STDOUT, "(paste SCM-CANVAS/1.0 … END; empty line cancels)\n");
            $body = '';
            while (true) {
                $more = read_line('... ');
                if ($more === null) {
                    break 2;
                }
                $more = rtrim($more, "\r\n");
                if ($body === '' && $more === '') {
                    fwrite(STDOUT, "cancelled\n");
                    break 2;
                }
                $body .= $more . "\n";
                if ($more === 'END') {
                    break;
                }
            }
            print_result(request_raw($body, $root, $sockPath, $direct));
            break;
        case 'generate':
        case 'gen':
            $model = $rest !== '' ? $rest : $defaultModel;
            if (!preg_match('/^[A-Za-z0-9._-]{1,128}\.gguf$/', $model)) {
                fwrite(STDOUT, "REJECT: REPL:bad_model\n");
                break;
            }
            print_result(request_json([
                'op' => 'generate',
                'model' => $model,
            ], $root, $sockPath, $direct));
            break;
        case 'register':
            $bits = preg_split('/\s+/', $rest, 2);
            $name = $bits[0] ?? '';
            $source = $bits[1] ?? '';
            if ($name === '' || $source === '') {
                fwrite(STDOUT, "usage: register <name.gguf> </abs/path.gguf>\n");
                break;
            }
            print_result(request_json([
                'op' => 'register_gguf',
                'name' => $name,
                'source' => $source,
            ], $root, $sockPath, $direct));
            break;
        case 'json':
            if ($rest === '') {
                fwrite(STDOUT, "usage: json {\"op\":\"ping\"}\n");
                break;
            }
            $msg = json_decode($rest, true);
            if (!is_array($msg)) {
                fwrite(STDOUT, "REJECT: REPL:bad_json\n");
                break;
            }
            print_result(request_json($msg, $root, $sockPath, $direct));
            break;
        default:
            fwrite(STDOUT, "unknown command (type help)\n");
            break;
    }
}

function print_banner(string $root, string $sock, bool $direct): void
{
    fwrite(STDOUT, "Sovereign Canvas Machine — REPL\n");
    fwrite(STDOUT, "root:   $root\n");
    if ($direct) {
        fwrite(STDOUT, "mode:   direct (perl supervisor; no socket)\n");
    } else {
        $live = file_exists($sock) ? 'live' : 'not listening';
        fwrite(STDOUT, "socket: $sock ($live)\n");
        if ($live !== 'live') {
            fwrite(STDOUT, "hint:   php ingress/server.php &\n");
        }
    }
    fwrite(STDOUT, "type help · paste SCM-CANVAS/1.0 … END · quit to exit\n\n");
}

function print_help(string $defaultModel): void
{
    fwrite(STDOUT, <<<TXT
  help                 this text
  ping                 health
  models               list GGUFs
  file <rel/path>      propose a canvas file
  propose              multi-line canvas until END
  generate [model]     GGUF generate (default $defaultModel)
  register <n> <abs>   register local .gguf
  json {...}           raw JSON op
  quit                 exit

  Or paste a full SCM-CANVAS/1.0 record ending with END.

TXT);
}

function read_line(string $prompt): ?string
{
    if (function_exists('readline')) {
        $line = readline($prompt);
        if ($line === false) {
            return null;
        }
        if ($line !== '') {
            readline_add_history($line);
        }
        return $line;
    }
    fwrite(STDOUT, $prompt);
    fflush(STDOUT);
    $line = fgets(STDIN);
    return $line === false ? null : $line;
}

function safe_rel(string $path): bool
{
    if ($path === '' || $path[0] === '/' || str_contains($path, "\0") || str_contains($path, '..')) {
        return false;
    }
    return (bool)preg_match('#^[A-Za-z0-9._/-]+$#', $path);
}

function print_result(string $resp): void
{
    $resp = rtrim($resp);
    if ($resp === '') {
        fwrite(STDOUT, "(empty response)\n");
        return;
    }
    fwrite(STDOUT, $resp . "\n");
}

function request_json(array $msg, string $root, string $sock, bool $direct): string
{
    if ($direct && ($msg['op'] ?? '') === 'propose' && ($msg['format'] ?? '') === 'canvas') {
        if (isset($msg['path'])) {
            $path = (string)$msg['path'];
            if (!safe_rel($path)) {
                return "REJECT: REPL:bad_path\n";
            }
            $full = $root . '/' . $path;
            if (!is_readable($full)) {
                return "REJECT: REPL:path_missing\n";
            }
            $body = file_get_contents($full);
            return $body === false ? "REJECT: REPL:path_read\n" : request_raw((string)$body, $root, $sock, true);
        }
        if (isset($msg['body'])) {
            return request_raw((string)$msg['body'], $root, $sock, true);
        }
    }
    if ($direct && in_array($msg['op'] ?? '', ['ping', 'list_models'], true)) {
        if (($msg['op'] ?? '') === 'ping') {
            return "PONG (direct)\n";
        }
        return "MODELS: (start ingress for list)\n";
    }
    if ($direct) {
        return "REJECT: REPL:need_socket_for_" . ($msg['op'] ?? 'op') . "\n";
    }
    return socket_exchange($sock, json_encode($msg, JSON_UNESCAPED_SLASHES) ?: '{}');
}

function request_raw(string $text, string $root, string $sock, bool $direct): string
{
    if ($direct) {
        return run_supervisor($text, $root);
    }
    return socket_exchange($sock, $text);
}

function socket_exchange(string $sock, string $payload): string
{
    if (!file_exists($sock)) {
        return "REJECT: REPL:no_socket ($sock)\n";
    }
    $fp = @stream_socket_client("unix://$sock", $errno, $errstr, 5);
    if ($fp === false) {
        return "REJECT: REPL:connect:$errstr\n";
    }
    fwrite($fp, $payload);
    if ($payload !== '' && $payload[-1] !== "\n") {
        fwrite($fp, "\n");
    }
    stream_socket_shutdown($fp, STREAM_SHUT_WR);
    $resp = stream_get_contents($fp);
    fclose($fp);
    return $resp === false ? "REJECT: REPL:no_response\n" : $resp;
}

function run_supervisor(string $text, string $root): string
{
    $supervisor = $root . '/perl/scm_supervisor.pl';
    if (!is_file($supervisor)) {
        return "REJECT: REPL:no_supervisor\n";
    }
    $descriptors = [
        0 => ['pipe', 'r'],
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];
    $proc = proc_open(
        ['perl', $supervisor],
        $descriptors,
        $pipes,
        $root,
        [
            'SCM_ROOT' => $root,
            'PATH' => getenv('PATH') ?: '/usr/local/bin:/usr/bin:/bin',
        ]
    );
    if (!is_resource($proc)) {
        return "REJECT: REPL:exec\n";
    }
    fwrite($pipes[0], $text);
    fclose($pipes[0]);
    $out = stream_get_contents($pipes[1]);
    $err = stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    proc_close($proc);
    $line = is_string($out) ? $out : '';
    if ($line !== '' && $line[-1] !== "\n") {
        $line .= "\n";
    }
    if (is_string($err) && trim($err) !== '') {
        foreach (explode("\n", trim($err)) as $t) {
            if ($t !== '') {
                fwrite(STDERR, "  | $t\n");
            }
        }
    }
    return $line === '' ? "REJECT: REPL:no_output\n" : $line;
}
