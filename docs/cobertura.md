# Cobertura y criterios de aceptación

La batería [`tests/pruebas.pl`](../tests/pruebas.pl) contiene **61 pruebas funcionales**. En la validación inicial con GNU Prolog 1.5.0 en Linux se obtuvieron **61 correctas, 0 fallidas**, con código de salida 0. Este documento distingue lo comprobado por esas pruebas de las mediciones de rendimiento y la revisión del código.

Desde la raíz del proyecto, con GNU Prolog y sus auxiliares en `PATH`:

```sh
gprolog --consult-file horarios.pl \
  --consult-file tests/pruebas.pl --entry-goal pruebas
```

La batería termina con código 1 si alguna prueba falla. También invoca `sh horarios.sh` y consulta los hechos exportados en otro proceso GNU Prolog. El prefijo `sh` permite ejecutarla en volúmenes donde el sistema de archivos no admite ejecutar directamente archivos `.sh`.

Los archivos temporales se escriben bajo `/tmp/horarios-pruebas-*`. La prueba de rutas utiliza además `/tmp/horarios prueba d'entrada.dat` y `/tmp/horarios prueba d'salida.txt`. No ejecutar dos copias simultáneas de esta batería, porque comparten esos nombres. `system/2` se usa exclusivamente para pruebas de integración; la lectura de las instancias del programa está implementada en GNU Prolog.

## Instancias y resultados esperados

| Archivo en `instancias/` | Sesiones | Propósito |
| --- | ---: | --- |
| `campus-central.dat` | 10 | Registros del ejemplo de la sección 5.8 del PDF, con 18 franjas-sesión. |
| `pequena.dat` | 3 | Instancia resoluble con dos tipos de aula, duración 1 y 2, co-docencia, aula fija, prohibición y preferencias. |
| `escala-20.dat` | 20 | Instancia resoluble con cinco grupos de cuatro sesiones. |
| `escala-40.dat` | 40 | Instancia resoluble con diez grupos de cuatro sesiones. |
| `escala-80.dat` | 80 | Instancia resoluble con veinte grupos de cuatro sesiones. |
| `sin-solucion.dat` | 3 | Datos válidos y localmente coherentes; conflicto global entre tres grupos mutuamente excluyentes y dos franjas. |
| `invalida.dat` | — | Errores de sintaxis, claves, duplicados, tipos, números, rangos y referencias. |
| `blandas.dat` | 2 | Óptimo positivo conocido: costo 11. |
| `semantica.dat` | 3 | Secciones reordenadas, campos con espacios, UTF-8, co-docencia, tipos y grupos excluyentes. |
| `formato-crlf.dat` | 1 | Finales de línea CRLF y último registro sin salto de línea. |
| `salida-caracteres.dat` | 1 | Identificadores con coma, comillas dobles y UTF-8 para comprobar CSV y exportación Prolog. |

Las instancias crecientes asignan a cada grupo una pareja aula-día distinta, con cuatro posibles inicios para sus cuatro sesiones. Esta construcción garantiza que son resolubles; el programa no contiene sus horarios. Son casos estructurados para medir crecimiento del modelo y costo de las técnicas, y no representan todas las dificultades posibles de asignación de horarios. La batería comprueba los tres tamaños y resuelve la instancia de 20 sesiones con CLP(FD). Las ejecuciones completas de 40 y 80 forman parte de los experimentos de rendimiento.

En `sin-solucion.dat` hay tres aulas y tres profesores independientes, cada uno con demanda semanal 1. Los dominios individuales son no vacíos y los prechequeos necesarios pasan. Las tres restricciones `excluyentes` exigen tres franjas diferentes, pero solo hay dos. La ausencia de solución se demuestra mediante búsqueda, sin tratarla como un error de formato.

En `blandas.dat`, las prohibiciones eliminan L2 y L3. Las sesiones deben ocupar L1 y L4. La preferencia L2 cuesta 3 y quedan dos franjas vacías internas, con peso 4 cada una: `3 + 2 × 4 = 11`. Ambos motores deben devolver ese costo y marcar el óptimo demostrado.

## Correspondencia con el PDF

| Secciones | Requisito | Implementación y evidencia |
| --- | --- | --- |
| 3, 5, 7, 11 | Lectura y validación | `src/entrada.pl`; carga sucesiva, secciones reordenadas, espacios, CRLF, EOF, archivo ausente y acumulación de errores con línea. |
| 4.2, 7 | Sesiones y dominios | `src/modelo.pl`; cantidades 3, 10, 20, 40 y 80; poda por capacidad, tipo, aula fija, disponibilidad y fin de día. |
| 4.3 | Restricciones duras | `src/modelo.pl`; horarios deliberadamente corruptos para sesiones ausentes/duplicadas, capacidad, tipo, aula fija, solapamientos, exclusión, prohibición, disponibilidad, desbordamiento y máximo docente. |
| 4.4, 8.5 | Costo y optimización | `src/modelo.pl` y `src/busqueda.pl`; costo cero, óptimo positivo 11 con ambos motores, huecos por día y preferencia de inicio. |
| 8.1 | Backtracking | `src/busqueda.pl`; generación y prueba sin verificación anticipada, MRV con LCV, selección por grado y por demanda. |
| 8.2, 8.3 | Dominios finitos y heurísticas | `src/busqueda.pl`; llamadas a `fd_domain/3`, `fd_all_different/1` y `fd_labeling/2`; soluciones verificadas con `ff` y `ffc`, instancia de 20 sesiones, límite e imposibilidad. |
| 8.4 | Dos reducciones de simetría | `src/busqueda.pl`; orden cronológico de sesiones del mismo grupo y orden de primera utilización de aulas intercambiables. La batería ejecuta búsquedas con ambas activas; no enumera todas las soluciones con/sin simetría. |
| 6, 9 | Interfaz e informes | `src/cli.pl`, `src/salida.pl` y `horarios.sh`; invocación real y comprobación de encabezado, detalle, rejillas de grupo/profesor/aula, resumen y métricas. |
| 6.5, 13 | Exportaciones y extensión | `src/salida.pl`; un hecho `asignacion/7` por sesión, co-docencia, consulta en otro proceso, CSV con escape de comillas y conservación de UTF-8. |
| 10, 11 | Límites y fallos | Códigos 0, 2, 3, 4 y 64; límite sin horario parcial, archivo ausente, error de escritura y rechazo de argumentos incorrectos. |
| 11 | Diagnóstico | Primer prefijo declarado demostrado imposible, distinción entre base inviable y límite indeterminado, preservación de opciones, restricciones y métricas. |
| 10, 12, 14 | Compilación y análisis experimental | `compilar.sh` y `src/nativo.pl` proporcionan el modo nativo. Su validación y las tablas/gráficos de rendimiento se realizan aparte de estas 61 pruebas. |

`verifica/1` no llama a `dominio/2` ni a `compatible_asignaciones/2`: vuelve a comprobar las condiciones del horario completo. Se ejercita tanto con horarios válidos como con violaciones introducidas deliberadamente. Esto reduce el riesgo de reproducir en el verificador el mismo defecto de los motores de búsqueda.

La optimización aplica una cota inferior basada en preferencias que ya no pueden satisfacerse. Los huecos de una asignación parcial no se utilizan como cota, porque otra sesión podría rellenarlos. Si se completa la búsqueda o se alcanza costo cero, el programa puede demostrar optimalidad; alcanzar el límite no basta para hacerlo.

## Decisiones semánticas

- **Disponibilidad:** siguiendo la sección 4.3.6, se exige disponibilidad en la franja de inicio. Una sesión puede continuar fuera del rango de inicios disponibles si permanece dentro del día.
- **Co-docencia:** cada sesión ocupa a todos los profesores declarados para su grupo. Se exige la intersección de sus disponibilidades y todos reciben la duración completa en la carga semanal. No hay reparto automático de sesiones entre docentes.
- **Requerimiento `mixta`:** el PDF define restricciones específicas para teoría y laboratorio, pero no una restricción exclusiva para `mixta`. Se interpreta que admite cualquier tipo de aula. Teoría admite teoría/mixta; laboratorio admite laboratorio/mixta.
- **Prohibiciones:** se comprueban todas las franjas ocupadas, no solo el inicio. Dos sesiones adyacentes no se solapan.
- **Preferencias:** cada declaración penaliza una vez si ninguna sesión del grupo comienza exactamente en el día y franja indicados.
- **Huecos:** cuentan solo franjas libres estrictamente entre la primera y la última franja ocupada en un mismo día. Los huecos de profesores se reportan; el costo incluye `prefiere` y `compacta` declaradas.
- **Identificadores:** se conserva el código original, incluyendo mayúsculas, guiones y UTF-8. Los hechos exportados usan átomos entrecomillados cuando corresponde. En `asignacion/7`, un docente se representa con un átomo y varios docentes con una lista.
- **Límites:** finalizar por límite no demuestra insatisfacibilidad ni optimalidad. Puede conservarse el mejor horario completo encontrado, pero nunca una asignación parcial como solución válida.
- **Diagnóstico:** el primer prefijo incompatible no es un núcleo mínimo insatisfacible. El diagnóstico también tiene un límite y puede devolver una causa indeterminada.

## Alcance de la validación

Las pruebas demuestran los comportamientos indicados para los casos incluidos; no sustituyen una prueba formal de corrección para cualquier instancia. No miden porcentajes de cobertura de cláusulas. La comparación interpretado/nativo, la aceleración, la eficiencia de poda y el comportamiento de 40/80 sesiones requieren las mediciones y el análisis del informe técnico.

Como ampliaciones futuras de las pruebas, serían útiles la comparación exhaustiva de óptimos con/sin simetría en instancias diminutas y la enumeración de todos los errores individuales del parser. No son funcionalidades adicionales exigidas al usuario para ejecutar el proyecto.
