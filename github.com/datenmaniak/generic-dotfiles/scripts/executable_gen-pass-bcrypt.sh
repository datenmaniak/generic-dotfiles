#!/bin/bash

# Uso: ./gen-bcrypt.sh "tu_contraseña"

if [ $# -eq 0 ]; then
    echo "Error: falta la contraseña."
    echo "Uso: $0 \"contraseña\""
    exit 1
fi

PASSWORD="$1"

python3 -c "
import sys
import bcrypt

password = sys.argv[1].encode('utf-8')
salt = bcrypt.gensalt(rounds=12)
hash_bcrypt = bcrypt.hashpw(password, salt)
print(hash_bcrypt.decode('utf-8'))
" "$PASSWORD"
