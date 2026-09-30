#!/bin/sh
# Solo invoca el compilador; el banco y las graficas se ejecutan en Prolog.
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$base"
exec "${GPLC:-gplc}" --no-top-level --global-size 131072 --local-size 65536 --trail-size 65536 --cstr-size 131072 -o bin/experimentos horarios.pl experimentos.pl src/experimentos_nativo.pl
