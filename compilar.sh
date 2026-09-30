#!/bin/sh
# Envoltura de compilacion; ejecutar desde cualquier directorio.
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$base"
exec "${GPLC:-gplc}" --no-top-level --global-size 131072 --local-size 65536 --trail-size 65536 --cstr-size 131072 -o bin/horarios horarios.pl src/nativo.pl
