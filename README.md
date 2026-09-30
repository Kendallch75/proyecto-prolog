# Asignación de horarios universitarios en GNU Prolog

Proyecto desarrollado a partir de [logicos.pdf](logicos.pdf). El lector, la validación, ambos motores de búsqueda, el diagnóstico, los experimentos y las exportaciones están escritos en **GNU Prolog**. Los guiones de shell solo invocan el intérprete o el compilador. No necesita conexión a Internet para funcionar.

## Inicio rápido

En Ubuntu/Debian, instalar GNU Prolog y las herramientas para compilar:

```sh
sudo apt update
sudo apt install gprolog build-essential
```

Desde la carpeta del proyecto:

```sh
sh horarios.sh instancias/campus-central.dat resultados/campus.txt clpfd \
  --heuristica=ff --optimizar --limite=500000 \
  --aulas --prolog=resultados/campus.pl --csv=resultados/campus.csv
```

En un sistema de archivos que permita ejecución, también se puede usar `chmod +x horarios.sh compilar.sh` y `./horarios.sh …`, como solicita el PDF. Esta carpeta está en una unidad FAT con la opción `showexec`: aquí hay que usar `sh horarios.sh …`. Para ejecutar binarios nativos, copiarlos a un directorio de Linux que permita ejecución, como `/tmp`.

## Formas de ejecución

```sh
# Backtracking con generación y comprobación al terminar
sh horarios.sh instancias/pequena.dat resultados/bt.txt bt

# Forward checking y mínimo dominio restante
sh horarios.sh instancias/campus-central.dat resultados/mrv.txt bt --heuristica=mrv

# MRV con valor menos restrictivo
sh horarios.sh instancias/pequena.dat resultados/lcv.txt bt --heuristica=mrv --valor=lcv

# Dominios finitos, branch and bound y límite explícito
sh horarios.sh instancias/campus-central.dat resultados/optimo.txt clpfd \
  --heuristica=ff --optimizar --limite=5000000

# Diagnóstico de una instancia coherente pero imposible
sh horarios.sh instancias/sin-solucion.dat resultados/diagnostico.txt clpfd

# Compilación nativa
sh compilar.sh
bin/horarios instancias/campus-central.dat resultados/nativo.txt clpfd --heuristica=ff
```

En esta unidad FAT, sustituir la última orden por:

```sh
cp bin/horarios /tmp/horarios-universitarios
chmod +x /tmp/horarios-universitarios
/tmp/horarios-universitarios instancias/campus-central.dat resultados/nativo.txt clpfd --heuristica=ff
```

Uso interactivo:

```text
gprolog --consult-file horarios.pl
| ?- main('instancias/pequena.dat', 'resultados/interactivo.txt', clpfd).
| ?- main('instancias/pequena.dat', 'resultados/optimo.txt', clpfd,
          ['--optimizar', '--heuristica=ff']).
| ?- cargar_instancia('instancias/pequena.dat'), sesiones(S).
| ?- dominio(sesion('MAT', 'G1', 1), D).
| ?- resolver(clpfd, H), verifica(H), costo(H, C).
```

`main/3` restablece las opciones; `main/4` permite modificarlas. Las consultas conservan exactamente los códigos del archivo, con comillas si comienzan por mayúscula o contienen guiones. `resolver/2` devuelve una solución completa; `ejecutar_busqueda/4` permite además inspeccionar el estado y la demostración de optimalidad.

## Opciones

| Opción | Uso |
|---|---|
| `--heuristica=original` | Orden de lectura; valor predeterminado de la CLI. |
| `--heuristica=mrv` o `ff` | Menor dominio actual; activa comprobación anticipada para BT. |
| `--heuristica=ffc` | MRV y desempate por grado. |
| `--heuristica=grado` | Más vecinos con posibles conflictos. |
| `--heuristica=demanda` | Mayor producto inscritos × sesiones × duración. |
| `--valor=original` o `lcv` | Orden inicial o valor que elimina menos opciones. |
| `--anticipada` | Comprobar conflictos y filtrar dominios durante BT. |
| `--sin-anticipada` | Comprobar conflictos binarios al completar BT. |
| `--optimizar` | Buscar el costo mínimo y certificarlo cuando termina. |
| `--limite=N` | Máximo de intentos de asignación; predeterminado 500000. Cero impide explorar decisiones. |
| `--sin-simetria` | Desactiva las dos reducciones de simetría. |
| `--aulas` | Añadir una rejilla por aula. |
| `--prolog=archivo.pl` | Exportar hechos `asignacion/7`. |
| `--csv=archivo.csv` | Exportar CSV, extensión del proyecto. |
| `--ayuda` | Mostrar ayuda. |

Las opciones se procesan de izquierda a derecha. Para el BT totalmente ingenuo, usar `--heuristica=original --sin-anticipada --sin-simetria`. El límite cuenta ramas explícitas, también las rechazadas por propagación; no es un límite de segundos, de memoria ni del trabajo interno del resolutor. El diagnóstico causal realiza búsquedas adicionales acotadas y conserva las métricas originales.

Las variables `GPROLOG` y `GPLC` permiten seleccionar ejecutables alternativos. El directorio de GNU Prolog debe estar en `PATH` para que se encuentre también `pl2wam`. La envoltura reserva pilas suficientes para las instancias incluidas; pueden ajustarse con `GLOBALSZ`, `LOCALSZ`, `TRAILSZ` y `CSTRSZ`, en KiB.

## Entrada y semántica

Los archivos `.dat` se leen íntegramente en Prolog, en UTF-8, con campos separados por `;`. Se aceptan BOM UTF-8, CRLF, última línea sin salto y espacios exteriores. Las secciones `#:CONFIG`, `#:AULA`, `#:PROFESOR`, `#:CURSO`, `#:IMPARTE`, `#:RESTRICCION` pueden aparecer en cualquier orden, una sola vez. `#` introduce comentarios en líneas completas; no se permiten comentarios al final de un registro.

`CONFIG` necesita `dias`, `franjas`, `inicio` y `duracion_franja`. Véase [campus-central.dat](instancias/campus-central.dat) para un ejemplo completo idéntico al del enunciado. Los números son enteros decimales no negativos; franjas, duración y sesiones semanales deben ser positivas. Una sesión debe caber dentro del día. Las referencias se comprueban después de leer todo el archivo.

Se aplican colisiones de grupo, profesor y aula; capacidad, tipo, disponibilidad, carga máxima; `aula_fija`, `prohibida` y `excluyentes`. Las restricciones blandas son `prefiere` (peso una vez si falta ese inicio) y `compacta` (peso por cada franja vacía interna de cada día).

Decisiones explícitas ante aspectos abiertos del PDF:

- La disponibilidad del profesor se exige **en el inicio**, según §4.3. Una sesión puede continuar fuera del rango de inicios disponibles.
- Un curso `teoria` admite aula `teoria` o `mixta`; `laboratorio` admite `laboratorio` o `mixta`; un curso `mixta` admite cualquiera de los tres tipos.
- Varios profesores en `IMPARTE` representan **codocencia**: todos participan en todas las sesiones. No se implementa reparto individual de sesiones.
- Un hueco es una franja vacía entre la primera y la última ocupadas **en el mismo día**. No se penalizan huecos implícitos adicionales; sí se informan los del grupo y del profesor.
- Las sesiones de un grupo pueden celebrarse el mismo día si no se solapan. El PDF no obliga a repartirlas en días diferentes.

## Resultados y códigos de salida

El informe incluye encabezado, detalle ordenado por curso/grupo/día, rejillas por grupo y profesor, resumen o diagnóstico y métricas. `Optimo demostrado: si` solo aparece cuando la optimización lo prueba; un límite nunca se presenta como ausencia de solución. Si había un horario completo antes del límite, se conserva ese horario, se vuelve a verificar y se indica que no se demostró optimalidad. Sin un horario completo, los archivos de exportación quedan vacíos (el CSV conserva la cabecera).

El archivo Prolog conserva los identificadores sin renombrarlos. Con un docente, el tercer argumento es un átomo; con codocencia es una lista ordenada de profesores, manteniendo **un hecho por sesión**. Ambos formatos se consultan directamente desde GNU Prolog.

| Código | Significado |
|---|---|
| 0 | Solución encontrada o ausencia de solución demostrada por búsqueda. Consultar el estado del informe. |
| 1 | Error inesperado del entorno o del programa. |
| 2 | Archivo ausente/ilegible, errores de formato/coherencia o inconsistencia detectada antes de buscar. |
| 3 | Límite de búsqueda alcanzado. |
| 4 | No se pudo escribir algún archivo de salida. |
| 64 | Argumentos incorrectos o rutas de entrada y salida coincidentes. |

Los errores de contenido indican su línea. La línea 0 señala un problema del archivo completo, como no poder abrirlo. Los directorios de salida deben existir. Los archivos indicados como salida se reemplazan.

## Pruebas y experimentos

```sh
gprolog --consult-file horarios.pl --consult-file tests/pruebas.pl --entry-goal pruebas
gprolog --consult-file horarios.pl --consult-file tests/simetrias.pl --entry-goal simetrias
```

La batería devuelve un código distinto de cero si falla. Incluye ambos motores, el verificador con horarios deliberadamente corruptos, entradas erróneas, límites y un óptimo positivo conocido.

[Metodología y reproducción de los experimentos](docs/experimentos.md), [informe técnico](docs/informe-tecnico.md), [cobertura del enunciado](docs/cobertura.md) y [guion de demostración](docs/demostracion.md).

## Archivos principales

| Archivo | Responsabilidad |
|---|---|
| `horarios.pl` | Carga de módulos. |
| `src/entrada.pl` | Lectura, UTF-8 y validación. |
| `src/modelo.pl` | Sesiones, dominios, costos y verificador independiente. |
| `src/busqueda.pl` | BT, CLP(FD), heurísticas, simetrías, optimización y diagnóstico causal. |
| `src/cli.pl` | Opciones, estados, códigos y coordinación. |
| `src/salida.pl` | Texto, rejillas, hechos Prolog y CSV. |
| `experimentos.pl` | Experimentos y gráficos generados en Prolog. |
| `instancias/` | Casos del PDF, tamaños crecientes y casos adversos. |
| `tests/` | Pruebas ejecutables en GNU Prolog. |
| `resultados/` | Ejemplos y mediciones reales. |

Referencia del lenguaje: [manual oficial de GNU Prolog 1.5.0](https://www.gprolog.org/manual/gprolog.html).
