% Regresion exhaustiva pequena, GNU Prolog, desde la raiz del proyecto:
% gprolog --consult-file horarios.pl --consult-file tests/simetrias.pl \
%         --entry-goal simetrias
%
% Dieciseis modelos x dos motores x simetrias si/no = 64 comparaciones.
% El oraculo enumera aulas e inicios sin llamar dominio/2 ni las podas del
% motor; verifica/1 decide la factibilidad de cada horario completo.
% Ocho modelos son SAT (optimos 0 o 7) y ocho son UNSAT por co-docencia.
% Se comprueba ademas que un limite conserve una solucion completa conocida
% sin anunciar optimalidad, aunque exista otra de menor costo.

simetrias :-
    ( catch(sim_comprobar, Error,
            (write('ERROR EN SIMETRIAS: '), writeq(Error), nl, fail)) ->
        write('RESULTADO: 64 comparaciones exhaustivas, 2 pruebas de limite y 3 de dominios grandes correctas.'), nl,
        halt(0)
    ; write('RESULTADO: prueba de simetrias fallida.'), nl, halt(1) ).

pruebas_simetrias :- simetrias.

% Entrada sin halt/1, util para incorporarla a otra bateria de pruebas.
sim_comprobar :-
    sim_modelos(0,15),
    sim_limite_con_mejor(bt),
    sim_limite_con_mejor(clpfd),
    sim_indice_mayor_127,
    sim_tiempo_mayor_127,
    sim_limite_vector_explicito.

sim_modelos(K,Fin) :- K > Fin, !.
sim_modelos(K,Fin) :-
    sim_preparar(K),
    sesiones(Sesiones),
    findall(Costo,
            (sim_bruto(Sesiones,Horario), verifica(Horario), costo(Horario,Costo)),
            Costos),
    sort(Costos,Ordenados),
    sim_oraculo_esperado(K,Ordenados),
    sim_combinaciones([bt-si,bt-no,clpfd-si,clpfd-no],K,Ordenados),
    write('OK   modelo '), write(K), write(': costos factibles '),
    write(Ordenados), nl,
    Siguiente is K+1, sim_modelos(Siguiente,Fin).

sim_oraculo_esperado(K,Costos) :-
    ( K < 4 -> Esperados = [0,7]
    ; K < 8 -> Esperados = [7]
    ; Esperados = [] ),
    ( Costos == Esperados -> true
    ; throw(oraculo_inesperado(K,esperado(Esperados),obtenido(Costos))) ).

sim_combinaciones([],_,_).
sim_combinaciones([Motor-Simetria|Cs],K,Costos) :-
    sim_opciones(Simetria),
    ( ejecutar_busqueda(Motor,H,Estado,Optimo),
      sim_resultado_correcto(Costos,H,Estado,Optimo) -> true
    ; throw(discrepancia(K,Motor,Simetria,costos_oraculo(Costos))) ),
    sim_combinaciones(Cs,K,Costos).

sim_resultado_correcto([],H,Estado,Optimo) :-
    H == [], Estado == sin_solucion, Optimo == no.
sim_resultado_correcto([Mejor|_],H,Estado,Optimo) :-
    Estado == solucion, Optimo == si,
    verifica(H), costo(H,Obtenido), Obtenido =:= Mejor.

sim_opciones(Simetria) :-
    opciones_defecto,
    cli_opcion(optimizar,si), cli_opcion(heuristica,ffc),
    cli_opcion(anticipada,si), cli_opcion(simetria,Simetria),
    cli_opcion(limite,100000).

sim_bruto([],[]).
sim_bruto([sesion(C,G,I)|Ss],[asig(C,G,I,A,D,F,Dur)|Hs]) :-
    grupo(C,G,_,_,_,Dur,_), aula(A,_,_),
    config(dias,Dias), member(D,Dias), config(franjas,Max),
    sim_entre(1,Max,F), sim_bruto(Ss,Hs).
sim_entre(A,B,A) :- A =< B.
sim_entre(A,B,X) :- A < B, Siguiente is A+1, sim_entre(Siguiente,B,X).

% Los bits de K activan aula_fija, excluyentes, prohibida y co-docencia.
% Dos aulas iguales ejercitan el orden GLOBAL de primer uso. aula_fija
% nombra la segunda aula para comprobar que no se la trate como permutable.
% El grupo c tiene dos sesiones indistinguibles y preferencias con compacta.
% FFC puede elegir primero el grupo d fijado, fuera del orden de lectura.
sim_preparar(K) :-
    ent_reiniciar,
    assertz(config(dias,[l])), assertz(config(franjas,3)),
    assertz(config(inicio,480)), assertz(config(duracion_franja,60)),
    assertz(aula(a,30,teoria)), assertz(aula(b,30,teoria)),
    assertz(profesor(p1,uno,9,todos)),
    assertz(profesor(p2,dos,9,todos)),
    assertz(profesor(p3,tres,9,todos)),
    assertz(grupo(c,g,curso_c,10,2,1,teoria)),
    assertz(grupo(d,g,curso_d,10,1,1,teoria)),
    assertz(grupo(e,g,curso_e,10,1,1,teoria)),
    assertz(imparte(c,g,p1)), assertz(imparte(d,g,p2)), assertz(imparte(e,g,p3)),
    assertz(restriccion(prefiere(c,g,l,2,3),1)),
    assertz(restriccion(compacta(c,g,4),2)),
    ( K mod 2 =:= 1 -> assertz(restriccion(aula_fija(d,g,b),3)) ; true ),
    ( K mod 4 >= 2 -> assertz(restriccion(excluyentes(d,g,e,g),4)) ; true ),
    ( K mod 8 >= 4 -> assertz(restriccion(prohibida(c,g,l,2),5)) ; true ),
    ( K >= 8 -> assertz(imparte(d,g,p1)), assertz(imparte(e,g,p1)) ; true ).

sim_limite_con_mejor(Motor) :-
    ent_reiniciar,
    assertz(config(dias,[l])), assertz(config(franjas,3)),
    assertz(config(inicio,480)), assertz(config(duracion_franja,60)),
    assertz(aula(a,30,teoria)), assertz(profesor(p,docente,3,todos)),
    assertz(grupo(c,g,curso,10,1,1,teoria)), assertz(imparte(c,g,p)),
    assertz(restriccion(prefiere(c,g,l,3,7),1)),
    sim_opciones(si), cli_opcion(heuristica,original), cli_opcion(limite,1),
    ( ejecutar_busqueda(Motor,H,Estado,Optimo),
      Estado == limite, Optimo == no, verifica(H), length(H,1), costo(H,7),
      metricas_busqueda(Nodos,_), Nodos =:= 1 -> true
    ; throw(limite_no_conserva_mejor(Motor)) ),
    cli_opcion(limite,100),
    ( ejecutar_busqueda(Motor,HOptimo,solucion,si),
      verifica(HOptimo), costo(HOptimo,0) -> true
    ; throw(reanudacion_no_encuentra_optimo(Motor)) ),
    write('OK   limite con mejor horario retenido: '), write(Motor), nl.

% Regresion del limite disperso 127 de GNU Prolog. Dos sesiones bloquean
% aulas a y b todo el dia: la primera asignacion viable de c es el indice129.
sim_indice_mayor_127 :-
    ent_reiniciar, fd_set_vector_max(127),
    assertz(config(dias,[l])), assertz(config(franjas,64)),
    assertz(aula(a,30,teoria)), assertz(aula(b,30,teoria)), assertz(aula(c,30,teoria)),
    assertz(profesor(p1,uno,64,todos)), assertz(profesor(p2,dos,64,todos)),
    assertz(profesor(p3,tres,1,todos)),
    assertz(grupo(a,g,bloque_a,10,1,64,teoria)),
    assertz(grupo(b,g,bloque_b,10,1,64,teoria)),
    assertz(grupo(c,g,libre,10,1,1,teoria)),
    assertz(imparte(a,g,p1)), assertz(imparte(b,g,p2)), assertz(imparte(c,g,p3)),
    assertz(restriccion(aula_fija(a,g,a),1)),
    assertz(restriccion(aula_fija(b,g,b),2)),
    dominio(sesion(c,g,1),D), length(D,192),
    sim_opciones(si),
    ( ejecutar_busqueda(bt,HBT,solucion,si), verifica(HBT),
      ejecutar_busqueda(clpfd,HFD,solucion,si), verifica(HFD),
      member(asig(c,g,1,c,l,1,1),HFD), fd_vector_max(Max), Max >= 192 -> true
    ; throw(candidato_129_perdido) ),
    write('OK   FD conserva el primer candidato valido, indice 129 de 192.'), nl.

% Una disponibilidad con un solo inicio puede tener indice1 y tiempo global
% superior a127; no basta dimensionar segun la longitud de los dominios.
sim_tiempo_mayor_127 :-
    ent_reiniciar, fd_set_vector_max(127),
    assertz(config(dias,[l])), assertz(config(franjas,140)),
    assertz(aula(a,30,teoria)),
    assertz(profesor(p,docente,1,[slot(l,130)])),
    assertz(grupo(c,g,curso,10,1,1,teoria)), assertz(imparte(c,g,p)),
    sim_opciones(si),
    ( ejecutar_busqueda(clpfd,H,solucion,si), verifica(H),
      H == [asig(c,g,1,a,l,130,1)] -> true
    ; throw(tiempo_130_perdido) ),
    write('OK   FD conserva un inicio 130 aunque haya un unico candidato.'), nl.

% El limite interno de GNU Prolog es1000000: su rechazo debe ser un error
% explicito, nunca convertirse en la falsa afirmacion de insatisfacibilidad.
sim_limite_vector_explicito :-
    ent_reiniciar,
    assertz(config(dias,[l])), assertz(config(franjas,1000001)),
    assertz(aula(a,30,teoria)),
    assertz(profesor(p,docente,1,[slot(l,1)])),
    assertz(grupo(c,g,curso,10,1,1,teoria)), assertz(imparte(c,g,p)),
    sim_opciones(si),
    ( catch((ejecutar_busqueda(clpfd,_,_,_),Resultado=sin_error),Error,Resultado=Error),
      Resultado = error(representation_error(fd_vector_max),_) -> true
    ; throw(limite_vector_no_reportado) ),
    write('OK   desbordar el vector FD produce un error explicito.'), nl.
