# Experimentos reproducibles

El banco [experimentos.pl](../experimentos.pl) realiza la carga, la validación, la búsqueda, la verificación independiente, las mediciones y la generación de CSV y SVG íntegramente en GNU Prolog. Los archivos entregados [interpretado.csv](../resultados/interpretado.csv) e [interpretado.svg](../resultados/interpretado.svg) contienen 35 mediciones completas: siete configuraciones para cinco instancias. Un estado `limite` es un resultado de la medición y no significa que la instancia sea irresoluble.

## Entorno y reproducción

Las mediciones interpretadas entregadas se realizaron en Linux de 64 bits con GNU Prolog 1.5.0. Se reservan 65536 KB de pila local y 131072 KB de pila global; no representan la memoria realmente consumida. La configuración `bt_grado` de 80 sesiones supera la pila local predeterminada de 16 MB en este entorno. El límite de nodos no limita el consumo de memoria ni el tiempo de modelado o de cálculo de heurísticas.

Desde la raíz del proyecto, con `gprolog` y sus programas auxiliares en `PATH` y el directorio `resultados` existente:

```sh
LOCALSZ=65536 GLOBALSZ=131072 gprolog \
  --consult-file horarios.pl \
  --consult-file experimentos.pl \
  --entry-goal "(experimentos(interpretado,'resultados/interpretado.csv','resultados/interpretado.svg')->halt;halt(1))"
```

Para contrastar la duración del proceso con el reloj externo del sistema:

```sh
time env LOCALSZ=65536 GLOBALSZ=131072 gprolog \
  --consult-file horarios.pl \
  --consult-file experimentos.pl \
  --entry-goal "(experimentos(interpretado,'resultados/interpretado.csv','resultados/interpretado.svg')->halt;halt(1))"
```

La orden `time` mide todo el proceso, incluido el arranque, la compilación a bytecode, las repeticiones y la escritura de resultados. No debe compararse directamente con una sola fila del CSV. Los comandos de shell únicamente invocan programas; no procesan las instancias ni calculan resultados.

El predicado también admite `experimentos(nativo,ArchivoCSV,ArchivoSVG)`. La etiqueta identifica el modo utilizado: no compila el programa por sí sola. Para medir código nativo hay que compilar `horarios.pl`, `experimentos.pl` y un punto de entrada que invoque ese predicado con `gplc`, utilizando los mismos límites y tamaños de pila. La entrega incorpora las siguientes invocaciones:

```sh
sh compilar-experimentos.sh
LOCALSZ=65536 GLOBALSZ=131072 ./bin/experimentos
```

Si el volumen del proyecto no permite ejecutar binarios, cópielo a un directorio ejecutable y mantenga la raíz del proyecto como directorio de trabajo:

```sh
cp bin/experimentos /tmp/horarios-experimentos
chmod +x /tmp/horarios-experimentos
LOCALSZ=65536 GLOBALSZ=131072 /tmp/horarios-experimentos
```

El manual principal contiene los detalles de compilación y las rutas de salida del programa nativo.

## Matriz de ejecución

| Instancia | Sesiones | Características |
|---|---:|---|
| `pequena.dat` | 3 | Dos tipos de aula, profesor compartido, preferencias y compactación. |
| `campus-central.dat` | 10 | Ejemplo completo del documento de especificaciones. |
| `escala-20.dat` | 20 | Grupos de cuatro sesiones con día y aula restringidos. |
| `escala-40.dat` | 40 | Misma estructura que la escala anterior con más grupos. |
| `escala-80.dat` | 80 | Misma estructura con veinte grupos. |

| Configuración | Motor y selección | Comprobación anticipada | Simetría | Criterio de parada |
|---|---|---|---|---|
| `bt_ingenuo` | BT, orden original y valor original | No | No | Primera solución |
| `bt_mrv` | BT, MRV y valor original | Sí | Sí | Primera solución |
| `bt_grado` | BT, grado y valor original | Sí | Sí | Primera solución |
| `bt_demanda` | BT, demanda y valor original | Sí | Sí | Primera solución |
| `bt_lcv` | BT, MRV y valor menos restrictivo | Sí | Sí | Primera solución |
| `clpfd_ff` | Dominios finitos, first-fail y valor original | Propagación FD | Sí | Primera solución |
| `clpfd_opt` | Dominios finitos, first-fail y branch and bound | Propagación FD | Sí | Óptimo demostrado |

Todas las configuraciones tienen el mismo límite de **5000 nodos por ejecución**. Un nodo es un intento explícito de asignación, incluidos intentos rechazados por propagación. Un retroceso es una rama abandonada antes de una parada terminal. Los contadores describen decisiones del motor implementado; no son el número de propagaciones internas de GNU Prolog.

## Medición y columnas

El intervalo medido empieza antes de `cargar_instancia/1` y termina después de verificar el horario completo y calcular su costo. Incluye lectura, validación, construcción de sesiones y dominios, prechequeos, imposición de restricciones, búsqueda y verificación independiente. Excluye las opciones del banco, el arranque de GNU Prolog y la escritura de CSV/SVG.

`statistics(runtime,...)` mide CPU y `statistics(real_time,...)` mide tiempo de pared, en milisegundos. El banco convierte ambos a segundos. Para `pequena` se ejecuta el proceso completo **100 veces** y se registra el promedio, porque una ejecución puede durar menos de un milisegundo. Los nodos y retrocesos registrados son los de una ejecución, no la suma de las cien; las salidas se comprueban iguales entre repeticiones. Las otras instancias se ejecutan una vez por configuración. Por tanto, las 35 filas representan 728 ejecuciones individuales.

Las columnas son:

- `modo`, `instancia`, `sesiones`, `configuracion`: identificación del experimento.
- `estado`: `solucion`, `limite` o `sin_solucion`; `invalida` y `error` permiten identificar fallos de entrada o ejecución.
- `costo`: penalización del horario completo encontrado, o `na` si no se encontró uno. Alcanzar el límite puede conservar una solución completa previa.
- `optimo`: `si` únicamente cuando la búsqueda de optimización terminó con la optimalidad demostrada.
- `nodos`, `retrocesos`: contadores por ejecución.
- `cpu_s`, `pared_s`: segundos por ejecución, promediados cuando corresponde.
- `aceleracion`: `CPU_BT_ingenuo / CPU_configuracion`.
- `eficiencia`: `(nodos_BT_ingenuo - nodos_configuracion) / nodos_BT_ingenuo`.

Los dos cocientes quedan vacíos si alguna búsqueda fue interrumpida, si algún tiempo de CPU es cero o si la referencia no exploró nodos. También quedan vacíos para `clpfd_opt`: demostrar un mínimo tiene un criterio de parada diferente del de obtener la primera solución. La eficiencia puede ser negativa si una configuración explora más nodos; no se recorta para ocultarlo. Una fila `error` no es una medición válida: sus ceros de sesiones y contadores son valores de sustitución y el detalle se informa en la salida de error.

Comparar nodos entre motores ayuda a explicar su comportamiento, pero no iguala el trabajo de cada nodo. La comparación contra BT ingenuo combina anticipación, heurísticas y simetría, por lo que no aísla el efecto de una sola técnica. Las configuraciones que buscan la primera solución pueden devolver costos distintos; los cocientes comparan factibilidad, no calidad del horario.

## Resultados interpretados entregados

Se encontraron soluciones en 31 de las 35 configuraciones; las otras cuatro alcanzaron el límite con BT ingenuo en campus y las tres escalas. No se encontraron filas `error` ni `invalida`. Se verificó de forma independiente cada horario devuelto.

| Instancia | BT ingenuo: nodos / estado | BT MRV: nodos / CPU (s) | BT grado: nodos / CPU (s) | CLPFD: nodos / CPU (s) | CLPFD óptimo: nodos / CPU (s) |
|---|---|---|---|---|---|
| Pequeña | 10 / solución | 3 / 0.000670 | 3 / 0.000870 | 3 / 0.000680 | 3 / 0.000650 |
| Campus | 5000 / límite | 10 / 0.006000 | 10 / 0.133000 | 30 / 0.022000 | 224 / 0.106000 |
| Escala 20 | 5000 / límite | 20 / 0.003000 | 20 / 0.026000 | 20 / 0.005000 | 20 / 0.006000 |
| Escala 40 | 5000 / límite | 40 / 0.014000 | 40 / 0.233000 | 40 / 0.023000 | 40 / 0.024000 |
| Escala 80 | 5000 / límite | 80 / 0.061000 | 80 / 1.934000 | 80 / 0.126000 | 80 / 0.126000 |

En la instancia pequeña, MRV redujo los intentos de 10 a 3: eficiencia de 0.70 y aceleración medida de aproximadamente 1.51. Sus soluciones iniciales tenían costos distintos (BT ingenuo: 0; MRV: 3), de modo que esta comparación demuestra rapidez para satisfacer las restricciones duras. No demuestra superioridad de costo.

En campus, MRV encontró una solución de costo 3 con 10 nodos. CLPFD con optimización encontró costo 0 con 224 nodos y certificó su optimalidad. La mayor exploración corresponde al objetivo adicional de minimizar penalizaciones. No se calculó aceleración respecto de BT ingenuo, porque este último terminó por límite y se desconoce cuánto habría tardado en completar su objetivo.

En la escala de 80 sesiones, MRV y grado exploraron 80 nodos, pero grado consumió 1.934 s frente a 0.061 s de MRV. Calcular conflictos entre dominios aporta trabajo aunque no reduzca la búsqueda. CLPFD también exploró 80 nodos y tardó 0.126 s, por lo que el menor número de decisiones no elimina el costo de construir y propagar restricciones.

El SVG utiliza barras horizontales con escala común `log10(1 + nodos)`. Un borde discontinuo identifica una corrida que alcanzó el límite. Cada barra incluye los nodos, el estado y la CPU; el CSV conserva más precisión. El documento SVG entregado tiene 35 barras y se comprobó que es XML bien formado.

## Alcance de las conclusiones

Las escalas 20, 40 y 80 son instancias estructuradas y resolubles con dominios pequeños. Su crecimiento no reproduce la dificultad de cualquier universidad: número de sesiones, tamaño de dominio, conflictos y preferencias afectan conjuntamente al problema. En estas escalas no hay restricciones blandas que exijan una búsqueda adicional; obtener costo cero ya demuestra el mínimo.

El banco entrega observaciones reproducibles, no intervalos de confianza. Salvo la instancia pequeña, se dispone de una medición por combinación. La planificación del sistema operativo, las cachés, el hardware, los recorridos de listas y el mantenimiento de hechos dinámicos influyen en los tiempos. Los promedios de la instancia pequeña reducen la cuantización del reloj, pero no sustituyen múltiples campañas independientes.

Para comparar interpretado y nativo deben usarse las mismas instancias, opciones, número de repeticiones y definición de tiempo. El etiquetado del CSV, por sí solo, no acredita una ejecución nativa. Debe conservarse el comando de compilación y confirmar que se ejecutó el binario generado por `gplc`.
