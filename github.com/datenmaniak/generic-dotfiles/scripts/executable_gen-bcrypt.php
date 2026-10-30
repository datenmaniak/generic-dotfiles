#!/usr/bin/env php
<?php

// Uso: php gen-bcrypt.php "tu_contraseña"

if ($argc < 2) {
    fwrite(STDERR, "Error: falta la contraseña.\n");
    fwrite(STDERR, "Uso: {$argv[0]} \"contraseña\"\n");
    exit(1);
}

$password = $argv[1];

$hash = password_hash($password, PASSWORD_BCRYPT);

echo $hash . "\n";
