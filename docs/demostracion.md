# Guion de demostración

Ejecutar desde la raíz del proyecto con GNU Prolog instalado. Duración orientativa: 10–15 minutos.

1. Mostrar `instancias/pequena.dat` y relacionar sus tres sesiones con `sesiones/1` y `dominio/2` en el intérprete.
2. Ejecutar `sh horarios.sh instancias/pequena.dat resultados/demo-bt.txt bt --sin-simetria`. Explicar la enumeración y el verificador final.
3. Repetir con `bt --heuristica=mrv --valor=lcv` y comparar nodos, retrocesos y CPU.
4. Ejecutar `sh horarios.sh instancias/campus-central.dat resultados/demo-campus.txt clpfd --heuristica=ff --optimizar --aulas --prolog=resultados/demo-campus.pl --csv=resultados/demo-campus.csv`. Mostrar las diez sesiones, las dieciocho franjas-sesión, el costo y las rejillas.
5. Ejecutar `sh horarios.sh instancias/blandas.dat resultados/demo-blandas.txt clpfd --optimizar`. Explicar por qué el costo mínimo es 11: dos huecos de peso 4 y una preferencia imposible de peso 3. Mostrar el certificado de optimalidad.
6. Ejecutar `sh horarios.sh instancias/sin-solucion.dat resultados/demo-imposible.txt clpfd`. Explicar el triángulo de exclusiones y el primer prefijo declarado imposible.
7. Ejecutar `sh horarios.sh instancias/invalida.dat resultados/demo-invalida.txt bt` y después `echo $?`. Mostrar varios errores con sus líneas y el código 2.
8. Ejecutar `sh horarios.sh instancias/campus-central.dat resultados/demo-limite.txt clpfd --limite=1`; después `echo $?`. Mostrar el estado `LIMITE ALCANZADO`, código 3 y ausencia de horario parcial.
9. Ejecutar `sh horarios.sh instancias/escala-80.dat resultados/demo-grande.txt clpfd --heuristica=ff` y mostrar los datos medidos.
10. Ejecutar la batería de pruebas y enseñar los gráficos de `resultados/`.

Para una modificación durante la defensa, copiar una instancia y cambiar capacidad, profesor, peso o franja prohibida. No modificar los originales de los experimentos sin regenerar las mediciones. El verificador se puede invocar sobre un horario con dos sesiones deliberadamente superpuestas: debe fallar incluso si no se utiliza el motor de búsqueda.

Preguntas para preparar: diferencia entre factibilidad y optimalidad; por qué los huecos de una solución parcial no son una cota inferior segura; qué significa cada nodo; por qué no se pueden intercambiar aulas mencionadas en `aula_fija`; qué trabajo mide el tiempo de CPU; por qué un límite no demuestra que una instancia sea imposible.
