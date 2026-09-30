#!/bin/sh
# Solo envoltura: todos los argumentos y archivos se procesan en GNU Prolog.
set -eu
# Tamano de pilas en KiB; el usuario puede sobrescribirlo por entorno.
GLOBALSZ=${GLOBALSZ:-131072}
LOCALSZ=${LOCALSZ:-65536}
TRAILSZ=${TRAILSZ:-65536}
CSTRSZ=${CSTRSZ:-131072}
export GLOBALSZ LOCALSZ TRAILSZ CSTRSZ
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "${GPROLOG:-gprolog}" --consult-file "$base/horarios.pl" --entry-goal cli -- "$@"
