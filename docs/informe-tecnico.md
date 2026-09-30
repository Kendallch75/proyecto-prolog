# Informe técnico: asignación de horarios universitarios

Este documento describe la implementación correspondiente a `logicos.pdf`, «Asignación de Horarios Universitarios con GNU Prolog», fechado el 16 de septiembre de 2026. El sistema está destinado a Linux y GNU Prolog 1.5.0. El [manual](../README.md) contiene los comandos y la [matriz de cobertura](cobertura.md) relaciona los requisitos con los archivos y las pruebas.

## Arquitectura y representación

`horarios.pl` incluye cinco módulos. `entrada.pl` lee y valida la instancia; `modelo.pl` define sesiones, dominios, restricciones y costos; `busqueda.pl` contiene los dos motores; `salida.pl` genera informes y exportaciones; `cli.pl` coordina las etapas y los códigos de terminación. Los guiones de shell se limitan a invocar GNU Prolog o `gplc`. No se utiliza otro resolutor, un lector externo de instancias ni soluciones incorporadas al programa.

La base de hechos usa:

```prolog
config(dias, ['L','M','X','J','V']).
config(franjas, 7).
config(inicio, 420).
config(duracion_franja, 60).
aula('A-101', 45, teoria).
profesor('P-001', 'Ana Rojas', 12, [slot('L',1),slot('L',2)]).
grupo('IC-1802', 'C1', 'Introduccion a la Programacion', 35, 2, 2, teoria).
imparte('IC-1802', 'C1', 'P-001').
restriccion(prefiere('IC-1802','C1','L',1,3), 42).
```

El último argumento de `restriccion/2` conserva la línea de procedencia. Los códigos se mantienen exactamente como aparecen en la entrada; no se transforman a minúsculas ni se sustituyen guiones. `profesor/4` admite `todos` para disponibilidad total.

Cada sesión tiene identidad `sesion(Curso,Grupo,Numero)`. Una decisión concreta se representa como `asig(Curso,Grupo,Numero,Aula,Dia,Inicio,Duracion)`. Se crean tantas sesiones como indique `semanales`, en el orden de lectura de los grupos. Un horario es una lista completa de estas decisiones. Los hechos exportados omiten el número interno y tienen la aridad `asignacion/7` solicitada.

`sesiones/1` enumera las sesiones y `dominio/2` calcula sus candidatos. `cargar_instancia/1` reemplaza la base anterior y falla si hay errores. `valida/1` devuelve todos los errores de coherencia y lectura. `resolver/2` entrega un horario completo; `ejecutar_busqueda/4` expone además el estado y la optimalidad. `verifica/1` comprueba un horario ya instanciado. Los modos esperados se documentan en los comentarios y en el manual; las interfaces de carga y búsqueda requieren argumentos de entrada conocidos, mientras los predicados de hechos y pertenencia permiten consultas relacionales.

## Lectura y validación

El lector utiliza `open/4` en modo binario y `get_byte/2`. Reconstruye líneas y campos mediante recursión, valida secuencias UTF-8, elimina un BOM inicial y recorta espacios, tabuladores y CR de los extremos. Reconoce comentarios, secciones y registros separados por punto y coma, incluso si la última línea termina directamente en EOF.

La validación se realiza en dos etapas. Durante la lectura se comprueban aridades, números, campos obligatorios, duplicados y formatos. Después se comprueban claves CONFIG, referencias entre secciones, días, franjas, duraciones y docentes por grupo. Esto permite cualquier orden de las secciones. Los errores se acumulan con su número de línea, en lugar de detenerse en el primero. Los rangos de disponibilidad se expanden solo después de verificar sus extremos, evitando crear listas enormes a partir de un rango inválido.

Los errores sintácticos se distinguen de una instancia correctamente descrita pero imposible. Antes de buscar se detectan dominios vacíos, demanda del grupo superior al calendario, sobrecarga semanal del profesor, cantidad de inicios docentes insuficiente y demanda superior a la capacidad total de franjas-aula. Son condiciones necesarias, no una decisión completa de factibilidad; los conflictos combinatorios restantes se resuelven mediante búsqueda.

## Restricciones duras

Un candidato unario debe usar un aula con capacidad suficiente y tipo compatible, estar en un día declarado, comenzar en una franja válida y terminar dentro del día. También respeta todas las aulas fijas, las franjas prohibidas cubiertas por su intervalo y la disponibilidad inicial de todos sus profesores. Los límites semanales de profesores se comprueban sobre la demanda total, que es independiente de dónde se coloque cada sesión.

Para dos sesiones del mismo día, los intervalos semia abiertos `[F,F+Dur)` se solapan si `F1 < F2+Dur2` y `F2 < F1+Dur1`. En ese caso no pueden compartir aula, grupo, profesor ni una declaración de exclusión. Una prohibición afecta cualquier franja cubierta; una preferencia, en cambio, se refiere exclusivamente al inicio.

Se aplica literalmente la disponibilidad de **inicio** descrita en §4.3 del PDF. `requiere=mixta` acepta cualquiera de los tipos de aula, pues el texto no impone una exclusividad para ese requerimiento. Varios profesores por grupo se interpretan como codocencia: todos deben estar disponibles y ninguno puede coincidir con otra sesión. No se implementa reparto de sesiones entre docentes. Estas decisiones están visibles en el manual y probadas con `semantica.dat`.

## Backtracking y poda anticipada

La estrategia BT ingenua recorre los dominios unarios y construye una asignación completa antes de comprobar las restricciones binarias con el verificador. Para aislar el caso más ingenuo se desactivan también las simetrías. El orden original sigue el archivo; los valores mantienen el orden aula, día y franja.

Con comprobación anticipada, cada nueva asignación se compara inmediatamente con las anteriores. A continuación se eliminan los candidatos incompatibles de todas las sesiones pendientes: si algún dominio queda vacío, la rama se descarta. Este *forward checking* permite que MRV utilice los dominios restantes reales, en vez de sus tamaños iniciales.

Los contadores se mantienen con hechos dinámicos y `assertz/1` y `retract/1`, para que sus actualizaciones sobrevivan al retroceso de Prolog. Cada intento de asignación incrementa el contador de nodos antes de intentar la decisión. Una rama abandonada antes de una parada terminal incrementa el contador de retrocesos. No son contadores de todas las inferencias del motor de GNU Prolog.

## Modelado con dominios finitos

Cada sesión tiene una variable FD `V` que selecciona un índice entre 1 y el tamaño de su dominio unario. Se calculan dos listas paralelas de constantes, inicio absoluto y número de aula. `fd_element/3` relaciona `V` con las variables `T` y `A` que representan esos atributos. Con días numerados desde cero y `Fmax` franjas por día:

```text
T = indice_dia * Fmax + franja_inicio
```

Una sesión nunca cruza el fin de su día porque el dominio unario ya lo impide. Por tanto, las comparaciones entre intervalos de inicios absolutos también distinguen correctamente días diferentes.

Si dos sesiones comparten grupo, profesor o exclusión, se publica:

```prolog
(T1 + Dur1 #=< T2) #\/ (T2 + Dur2 #=< T1)
```

Si no comparten esos recursos, se permite además usar aulas diferentes:

```prolog
(T1 + Dur1 #=< T2) #\/ (T2 + Dur2 #=< T1) #\/ (A1 #\= A2)
```

`fd_all_different/1` se aplica a los inicios absolutos de las sesiones del mismo grupo. Es una restricción redundante válida: refuerza el modelo, pero no reemplaza las restricciones de intervalos para sesiones de varias franjas. No se aplica a los índices locales `V`, ya que el mismo índice puede significar valores diferentes en distintos dominios.

La enumeración consulta `fd_dom/2` después de la propagación para seleccionar variables y valores. Cada rama restringe `V` mediante `fd_domain(V,I,I)` y termina esa decisión con `fd_labeling([V],[])`. El etiquetado se controla por decisión para poder imponer un límite exacto de nodos e implementar LCV. El costo es que no se delega el recorrido completo en una única llamada a `fd_labeling/2`.

Las tablas de candidatos representan extensionalmente las restricciones unarias; las disyunciones entre intervalos son restricciones aritméticas FD. Los costos de compactación y las comprobaciones de simetría de aulas se calculan en Prolog durante la búsqueda. No se afirma que todo el problema esté modelado únicamente con tablas FD.

## Heurísticas

| Heurística | Criterio implementado |
|---|---|
| Original | Posición inicial de la sesión. |
| MRV / FF | Menor número de candidatos actuales. |
| FFC | MRV, con desempate por mayor grado. |
| Grado | Mayor cantidad de sesiones pendientes con alguna incompatibilidad posible. |
| Demanda | Mayor producto de inscritos, sesiones semanales y duración. |
| LCV | Menor cantidad de candidatos eliminados en las demás sesiones. |

MRV y `ff` tienen aquí la misma semántica de dominio mínimo. `ffc` usa el grado del grafo de sesiones definido en la implementación; no se presenta como una reproducción exacta del desempate interno de GNU Prolog. LCV opera sobre los candidatos actuales. Los empates restantes se resuelven establemente por el orden inicial.

El cálculo de grado inspecciona pares de dominios y LCV puntúa cada candidato. Si la búsqueda ya es sencilla, ese trabajo puede superar el ahorro de nodos. Las mediciones separan esta situación de la eficacia de la poda.

## Reducción de simetría

Se aplican dos mecanismos que preservan factibilidad y costo:

1. **Orden cronológico dentro del grupo.** La sesión `i` debe preceder a `i+1`. Ninguna restricción ni preferencia identifica el número interno de sesión, por lo que permutar esos números no cambia el horario real ni su costo.
2. **Orden del primer uso de aulas equivalentes.** Las aulas con la misma capacidad y tipo que no aparecen en ninguna declaración `aula_fija` se usan por primera vez en el orden en que fueron declaradas. Su intercambio global conserva disponibilidad, solapamientos y restricciones blandas.

El segundo chequeo examina solo el prefijo continuo asignado del orden original de sesiones. Esto evita podar incorrectamente cuando MRV decide antes una sesión posterior. Ordenar sesiones no cambia las aulas disponibles y renombrar aulas no cambia los tiempos: ambas reducciones pueden combinarse sin eliminar el último representante de una solución.

`tests/simetrias.pl` compara el óptimo y la factibilidad de ambos motores, con y sin simetría, frente a una enumeración exhaustiva independiente de 16 modelos pequeños. Estos incluyen aulas fijas, exclusiones, prohibiciones, codocencia y costos positivos; complementan la justificación, sin sustituirla por una afirmación basada solo en pruebas.

## Restricciones blandas y optimalidad

Una declaración `prefiere(C,G,D,F,W)` agrega `W` si ninguna sesión de ese grupo comienza exactamente en `(D,F)`. `compacta(C,G,W)` agrega `W` por cada franja libre entre la primera y la última ocupadas en un mismo día. Se agrupan y ordenan las franjas ocupadas para contar estos huecos; los extremos libres y el tiempo entre días no cuentan.

Con `--optimizar`, se conserva el mejor horario completo y su costo. La cota inferior parcial suma las preferencias que ya no pueden satisfacerse ni con las sesiones asignadas ni con los dominios restantes. Toda rama cuya cota sea mayor o igual al mejor costo se poda. La cota es admisible porque los pesos son no negativos y eliminar posibilidades futuras no puede hacer satisfecha una preferencia ya imposible.

**Los huecos parciales no se usan como cota inferior**: una sesión posterior podría rellenarlos. Su contribución provisional es cero; el costo real se calcula al completar un horario. Esta elección preserva exactitud, pero puede hacer lenta la demostración de un óptimo positivo en problemas grandes.

Se certifica optimalidad al agotar la búsqueda, con sus podas válidas, o al encontrar costo cero, que es una cota global por no negatividad. Sin `--optimizar` se devuelve la primera solución sin afirmar que sea óptima. Si se alcanza el límite después de encontrar alguna solución, se conserva el mejor horario completo y se informa `LIMITE ALCANZADO` y `Optimo demostrado: no`.

## Verificación independiente y salidas

`verifica/1` no llama a `dominio/2` ni a `compatible_asignaciones/2`. Comprueba de nuevo las identidades de sesión, su cantidad, rango y duración, todas las restricciones unarias, cada par de sesiones y la carga máxima del profesor. Rechaza duplicados, sesiones faltantes, términos incompletos y conflictos. Toda solución se verifica antes de exportarse.

El informe se ordena por curso, grupo y el orden de los días configurados; incluye franjas y horas, rejillas por grupo y profesor y, opcionalmente, por aula. Expone costo, huecos, cantidad de sesiones, ocupación, contadores, tiempo de CPU, tiempo de pared y tasa de exploración. Si CPU es inferior a la resolución de un milisegundo, la tasa se marca como no medible en vez de dividir por cero.

El espacio ingenuo es el producto indicado en §4.2. Se presenta su logaritmo decimal, calculado como suma de logaritmos, para evitar el desbordamiento de un entero por un producto exponencial. Este valor es descriptivo; la búsqueda usa dominios mucho menores.

Los hechos `asignacion/7` se escriben con `writeq/2` para que los identificadores sean consultables. El argumento de profesor es un átomo para un docente y una lista para codocencia; se conserva un hecho por sesión. La extensión CSV duplica las comillas interiores y cita los campos textuales. Las pruebas vuelven a consultar la exportación en otro proceso GNU Prolog y comprueban códigos con comas, comillas y caracteres UTF-8.

## Diagnóstico y tolerancia a errores

Se distinguen exactamente los cuatro estados del enunciado: solución, sin solución, límite e instancia inválida. Los códigos de proceso están documentados en el manual. Los fallos de apertura, errores de datos, inconsistencias previas y errores de escritura terminan con código distinto de cero.

Una instancia imposible informa sesiones frente a franjas-aula disponibles y el recurso con mayor demanda. Para investigar las restricciones declaradas, el diagnóstico resuelve primero la base sin restricciones duras declaradas y luego añade dichas restricciones en el orden de lectura. Solo señala `primera_inviable` cuando los prefijos anteriores son resolubles y el actual se demuestra imposible. Cada búsqueda diagnóstica tiene un límite de hasta 10000 nodos; si lo alcanza, la causa se marca indeterminada. No se confunde un diagnóstico limitado con una prueba de insatisfacibilidad.

Además se compara la reducción del total de valores después de la propagación inicial causada por cada restricción dura individual. La mayor reducción identifica la restricción individual con más poda inicial. Si todas producen cero, puede existir un conflicto conjunto, como en el triángulo de exclusiones de la instancia imposible. Este indicador no es un núcleo mínimo de insatisfacibilidad. El diagnóstico guarda y restaura opciones, restricciones, mejor solución y contadores de la búsqueda principal.

## Evaluación del rendimiento

El [documento de experimentos](experimentos.md) presenta comandos reproducibles, tablas, CPU, tiempo de pared, aceleración y eficiencia. Los [resultados interpretados](../resultados/interpretado.csv) y [nativos](../resultados/nativo.csv) conservan las mediciones; sus gráficos [interpretado](../resultados/interpretado.svg) y [nativo](../resultados/nativo.svg) son archivos SVG autónomos, generados por el propio Prolog.

Se comparan siete configuraciones en instancias de 3, 10, 20, 40 y 80 sesiones. Todas tienen un límite común de 5000 nodos. La instancia pequeña se repite 100 veces para reducir la cuantización de los tiempos; las demás se ejecutan una vez. Cada modo genera 35 filas. La CPU medida incluye lectura, validación, modelado, búsqueda, cálculo del costo y verificación. En los informes ordinarios se incluye también el diagnóstico causal si procede; los contadores siguen correspondiendo a la búsqueda original.

La aceleración se calcula como `T_ingenuo/T_configuración` y la eficiencia como `(N_ingenuo-N_configuración)/N_ingenuo`. Los cocientes quedan vacíos cuando el caso de referencia alcanza su límite, porque no se conoce el tiempo ni el número de nodos necesarios para que termine. La optimización también se excluye de esa comparación con primera solución por tener un objetivo distinto. No se presenta el tiempo de un corte como una resolución completa.

El análisis debe distinguir costos por nodo de número de decisiones. Grado y LCV recorren dominios; FD construye y propaga restricciones; todas las estrategias recorren listas y actualizan hechos dinámicos. El orden de las cláusulas y los valores determina qué solución aparece primero. Una instancia muy libre puede favorecer generación y prueba; una con conflictos tempranos suele favorecer anticipación. La compilación nativa reduce parte del costo de interpretación, pero no elimina la complejidad del modelo ni los recorridos de listas.

Las instancias de escala están construidas con dominios pequeños y restricciones estructuradas. Resolver 80 sesiones en ellas no acredita resolver cualquier instancia universitaria de ese tamaño. Los tiempos dependen del hardware y la carga del sistema. Los datos se entregan como observaciones reproducibles, sin intervalos de confianza ni extrapolaciones de rendimiento no medido.

## Extensiones y limitaciones

Se entrega CSV como extensión adicional a la optimización obligatoria. También se admiten identificadores UTF-8, codocencia y un diagnóstico causal acotado por prefijos. No se implementan reparto de docentes, almuerzo común, optimización lexicográfica ni un núcleo mínimo de restricciones incompatibles.

El límite configurable es de nodos: no limita directamente el tiempo empleado en construir el modelo, calcular una heurística o propagar restricciones, ni evita agotar la memoria en instancias arbitrariamente grandes. Las pilas se pueden ampliar mediante las variables de GNU Prolog indicadas en el manual. La cota de compactación débil puede volver costosa la optimización positiva. Los CSV y gráficos del banco solo se consideran mediciones válidas cuando su estado no es `error` ni `invalida`.

La implementación se prueba con GNU Prolog 1.5.0; otras versiones requieren repetir las pruebas. Los directorios de salida deben existir y los destinos indicados se reemplazan. La aplicación no requiere servicios externos durante la ejecución. La instalación inicial de GNU Prolog es un requisito del entorno, no una dependencia de red del resolutor.

## Referencias

- [Especificación del proyecto](../logicos.pdf).
- [Manual oficial de GNU Prolog 1.5.0](https://www.gprolog.org/manual/gprolog.html): dominios finitos, `fd_element/3`, etiquetado, estadísticas y entrada/salida.
- [Manual de uso del proyecto](../README.md), [cobertura](cobertura.md) y [demostración](demostracion.md).
