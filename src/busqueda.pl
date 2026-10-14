% Motor portable para GNU Prolog. No utiliza bibliotecas de SWI-Prolog.
% Los nodos son intentos explicitos de asignacion (incluidos los fallidos).
% Los retrocesos son ramas abandonadas antes de una parada terminal.
:- dynamic(bus_contador/2).
:- dynamic(bus_mejor/2).
:- dynamic(bus_corte/1).

resolver(Estrategia, Horario) :-
    ejecutar_busqueda(Estrategia, Horario, Estado, _),
    (Estado = solucion ; Estado = limite, Horario \= []).

metricas_busqueda(Nodos, Retrocesos) :-
    bus_contador(nodos, Nodos), bus_contador(retrocesos, Retrocesos).

bus_op(Clave, Valor) :- opcion(Clave, Elegido), !, Valor = Elegido.
bus_op(heuristica, mrv).
bus_op(valor, original).
bus_op(anticipada, si).
bus_op(optimizar, no).
bus_op(limite, 100000).
bus_op(simetria, si).

ejecutar_busqueda(Estrategia, Horario, Estado, Optimo) :-
    (Estrategia = bt ; Estrategia = clpfd), !,
    retractall(bus_contador(_, _)), retractall(bus_mejor(_, _)),
    retractall(bus_corte(_)),
    assertz(bus_contador(nodos, 0)),
    assertz(bus_contador(retrocesos, 0)),
    sesiones(Sesiones),
    ( inconsistencias([]), bus_tareas(Sesiones, 1, Tareas) ->
        ( bus_ejecuta(Estrategia, Tareas) -> true ; true )
    ; true ),
    bus_resultado(Horario, Estado, Optimo).

bus_tareas([], _, []).
bus_tareas([S|Ss], I, [tarea(S, D, I)|Ts]) :-
    dominio(S, D), D \= [], J is I + 1, bus_tareas(Ss, J, Ts).

bus_ejecuta(bt, Tareas) :- bus_bt(Tareas, []).
bus_ejecuta(clpfd, Tareas) :-
    bus_fd_prepara(Tareas),
    bus_fd_crea(Tareas, FD),
    bus_fd_restricciones(FD),
    bus_fd_grupos(FD, FD),
    bus_fd(FD, FD).

bus_resultado(H, Estado, Optimo) :-
    ( bus_mejor(H0, _) -> H = H0 ; H = [] ),
    ( bus_corte(limite) -> Estado = limite, Optimo = no
    ; bus_mejor(_, _) -> Estado = solucion,
        (bus_op(optimizar, si) -> Optimo = si ; Optimo = no)
    ; Estado = sin_solucion, Optimo = no ).

bus_parar :- bus_corte(_).
bus_incrementa(Clave) :-
    retract(bus_contador(Clave, N)), M is N + 1,
    assertz(bus_contador(Clave, M)).
bus_nodo :-
    bus_contador(nodos, N), bus_op(limite, Limite),
    ( N < Limite -> bus_incrementa(nodos)
    ; assertz(bus_corte(limite)), fail ).
bus_retorno :- (bus_parar -> true ; bus_incrementa(retrocesos)).

% BT basico conserva los dominios iniciales y comprueba las restricciones
% binarias solo al completar la asignacion. BT anticipado hace forward checking.
bus_bt(_, _) :- bus_parar, !.
bus_bt(Tareas, Asignadas) :- bus_poda(Asignadas, Tareas), !.
bus_bt([], Asignadas) :- !, bus_registra(Asignadas).
bus_bt(Tareas, Asignadas) :-
    bus_selecciona(Tareas, Elegida, Restantes),
    Elegida = tarea(_, Dominio, _),
    bus_valores(Dominio, Restantes, Valores),
    bus_bt_ramas(Valores, Restantes, Asignadas).

bus_bt_ramas([], _, _).
bus_bt_ramas(_, _, _) :- bus_parar, !.
bus_bt_ramas([A|As], Restantes, Asignadas) :-
    ( bus_nodo ->
        (bus_bt_intenta(A, Restantes, Asignadas), fail ; true),
        bus_retorno,
        bus_bt_ramas(As, Restantes, Asignadas)
    ; true ).

bus_bt_intenta(A, Restantes, Asignadas) :-
    ( bus_op(anticipada, si) ->
        bus_compatible_lista(A, Asignadas),
        bus_filtra_tareas(Restantes, A, Nuevas)
    ; Nuevas = Restantes ),
    bus_simetria([A|Asignadas]),
    bus_bt(Nuevas, [A|Asignadas]).

bus_compatible_lista(_, []).
bus_compatible_lista(A, [B|Bs]) :-
    compatible_asignaciones(A, B), bus_compatible_lista(A, Bs).
bus_filtra_tareas([], _, []).
bus_filtra_tareas([tarea(S, D, I)|Ts], A, [tarea(S, D1, I)|Rs]) :-
    bus_filtra_dominio(D, A, D1), D1 \= [],
    bus_filtra_tareas(Ts, A, Rs).
bus_filtra_dominio([], _, []).
bus_filtra_dominio([B|Bs], A, R) :-
    ( compatible_asignaciones(A, B) -> R = [B|Rs] ; R = Rs ),
    bus_filtra_dominio(Bs, A, Rs).

% GNU Prolog usa por defecto vectores dispersos limitados a 127. fd_element/3
% fuerza esa representacion incluso antes del primer etiquetado: sin ampliar
% el vector puede perder candidatos y producir falsos negativos. Se dimensiona
% ANTES de crear cualquier variable del problema y nunca se reduce el tamano.
% Tambien se cubren los codigos de aula y el extremo exclusivo del horario.
bus_fd_prepara(Tareas) :-
    bus_fd_max_dominio(Tareas,0,MaxDominio),
    findall(A,aula(A,_,_),Aulas), length(Aulas,NumAulas),
    config(dias,Dias), length(Dias,NumDias), config(franjas,Franjas),
    Extremo is NumDias*Franjas+1,
    Necesario is max(MaxDominio,max(NumAulas,Extremo)),
    fd_vector_max(Actual),
    ( Necesario =< Actual -> true
    ; fd_set_vector_max(Necesario) -> true
    ; throw(error(representation_error(fd_vector_max),
                  bus_fd_prepara(necesario(Necesario)))) ).
bus_fd_max_dominio([],Max,Max).
bus_fd_max_dominio([tarea(_,D,_)|Ts],Actual,Max) :-
    length(D,N), Siguiente is max(Actual,N),
    bus_fd_max_dominio(Ts,Siguiente,Max).

% CLP(FD): cada variable elige un indice del dominio unario. fd_element/3
% canaliza a inicio absoluto y aula. No hay tablas cuadraticas de combinaciones.
bus_fd_crea([], []).
bus_fd_crea([tarea(S, D, Pos)|Ts], [fd(S,D,V,Inicio,Aula,Dur,Pos)|Fs]) :-
    length(D, N), fd_domain(V, 1, N),
    D = [asig(_,_,_,_,_,_,Dur)|_],
    bus_codigos(D, Inicios, Aulas),
    fd_element(V, Inicios, Inicio), fd_element(V, Aulas, Aula),
    bus_fd_crea(Ts, Fs).

bus_codigos([], [], []).
bus_codigos([asig(_,_,_,A,D,F,_)|As], [T|Ts], [R|Rs]) :-
    bus_tiempo(D, F, T),
    findall(X, aula(X,_,_), Aulas), bus_indice(A, Aulas, 1, R),
    bus_codigos(As, Ts, Rs).
bus_tiempo(D, F, T) :-
    config(dias, Dias), config(franjas, N),
    bus_indice(D, Dias, 0, I), T is I * N + F.
bus_indice(X, [Y|_], I, I) :- X == Y, !.
bus_indice(X, [_|Xs], I, J) :- K is I + 1, bus_indice(X, Xs, K, J).
bus_nth(1, [X|_], X) :- !.
bus_nth(N, [_|Xs], X) :- M is N - 1, bus_nth(M, Xs, X).

bus_fd_restricciones([]).
bus_fd_restricciones([F|Fs]) :-
    bus_fd_pares(F, Fs), bus_fd_restricciones(Fs).
bus_fd_pares(_, []).
bus_fd_pares(fd(S1,D1,V1,T1,A1,L1,P1),
             [fd(S2,_,_,T2,A2,L2,_)|Fs]) :-
    ( bus_comparten_tiempo(S1, S2) ->
        ((T1 + L1 #=< T2) #\/ (T2 + L2 #=< T1))
    ; ((T1 + L1 #=< T2) #\/ (T2 + L2 #=< T1) #\/ (A1 #\= A2)) ),
    ( bus_op(simetria, si), S1 = sesion(C,G,I), S2 = sesion(C,G,J) ->
        (I < J -> T1 #< T2 ; T2 #< T1)
    ; true ),
    bus_fd_pares(fd(S1,D1,V1,T1,A1,L1,P1), Fs).

bus_comparten_tiempo(sesion(C,G,_), sesion(C,G,_)) :- !.
bus_comparten_tiempo(sesion(C,G,_), sesion(C2,G2,_)) :-
    imparte(C,G,P), imparte(C2,G2,P), !.
bus_comparten_tiempo(sesion(C,G,_), sesion(C2,G2,_)) :-
    ( restriccion(excluyentes(C,G,C2,G2),_)
    ; restriccion(excluyentes(C2,G2,C,G),_) ), !.

% all_different se aplica a los inicios del mismo grupo: una restriccion
% redundante correcta que refuerza la propagacion y no confunde indices locales.
bus_fd_grupos([], _).
bus_fd_grupos([fd(sesion(C,G,_),_,_,_,_,_,_)|Fs], Todos) :-
    bus_fd_inicios_grupo(Todos, C, G, Inicios),
    fd_all_different(Inicios),
    bus_fd_quita_grupo(Fs, C, G, Resto),
    bus_fd_grupos(Resto, Todos).
bus_fd_inicios_grupo([], _, _, []).
bus_fd_inicios_grupo([fd(sesion(C1,G1,_),_,_,T,_,_,_)|Fs], C, G, R) :-
    (C1 == C, G1 == G -> R = [T|Ts] ; R = Ts),
    bus_fd_inicios_grupo(Fs, C, G, Ts).
bus_fd_quita_grupo([], _, _, []).
bus_fd_quita_grupo([F|Fs], C, G, R) :-
    F = fd(sesion(C1,G1,_),_,_,_,_,_,_),
    (C1 == C, G1 == G -> R = Rs ; R = [F|Rs]),
    bus_fd_quita_grupo(Fs, C, G, Rs).

bus_fd(_, _) :- bus_parar, !.
bus_fd(Pendientes, Todos) :-
    bus_fd_asignadas(Todos, Asignadas),
    bus_simetria(Asignadas),
    bus_fd_tareas(Pendientes, Tareas),
    ( bus_poda(Asignadas, Tareas) -> true
    ; Pendientes = [] -> bus_registra(Asignadas)
    ; bus_selecciona(Tareas, tarea(_,Dominio,Pos), _),
      bus_fd_extrae(Pos, Pendientes, Elegida, Restantes),
      bus_quita_pos(Tareas, Pos, Otras),
      bus_valores(Dominio, Otras, Valores),
      bus_fd_ramas(Valores, Elegida, Restantes, Todos)
    ).

bus_fd_ramas([], _, _, _).
bus_fd_ramas(_, _, _, _) :- bus_parar, !.
bus_fd_ramas([A|As], Elegida, Restantes, Todos) :-
    ( bus_nodo ->
        (bus_fd_intenta(A, Elegida, Restantes, Todos), fail ; true),
        bus_retorno,
        bus_fd_ramas(As, Elegida, Restantes, Todos)
    ; true ).
bus_fd_intenta(A, fd(_,Dominio,V,_,_,_,_), Restantes, Todos) :-
    bus_indice(A, Dominio, 1, I),
    % Labeling controlado: se cuenta ANTES de restringir la rama. Asi el limite
    % tambien cubre las decisiones rechazadas por propagacion. La seleccion
    % externa permite LCV; fd_labeling/2 finaliza cada decision individual.
    fd_domain(V, I, I), fd_labeling([V], []),
    bus_fd(Restantes, Todos).

bus_fd_tareas([], []).
bus_fd_tareas([fd(S,D,V,_,_,_,Pos)|Fs], [tarea(S,Actual,Pos)|Ts]) :-
    fd_dom(V, Indices), bus_elementos(Indices, D, Actual),
    Actual \= [], bus_fd_tareas(Fs, Ts).
bus_elementos([], _, []).
bus_elementos([I|Is], D, [A|As]) :-
    bus_nth(I, D, A), bus_elementos(Is, D, As).
bus_fd_asignadas([], []).
bus_fd_asignadas([fd(_,D,V,_,_,_,_)|Fs], R) :-
    ( integer(V) -> bus_nth(V, D, A), R = [A|As] ; R = As ),
    bus_fd_asignadas(Fs, As).
bus_fd_extrae(Pos, [F|Fs], F, Fs) :- F = fd(_,_,_,_,_,_,Pos), !.
bus_fd_extrae(Pos, [F|Fs], E, [F|Rs]) :- bus_fd_extrae(Pos, Fs, E, Rs).
bus_quita_pos([], _, []).
bus_quita_pos([tarea(_,_,Pos)|Ts], Pos, Ts) :- !.
bus_quita_pos([T|Ts], Pos, [T|Rs]) :- bus_quita_pos(Ts, Pos, Rs).

% Heuristicas de variables. MRV/FF usan dominios ACTUALES; FFC desempata por
% grado. El grado cuenta vecinos con alguna incompatibilidad posible.
bus_selecciona([T|Ts], E, R) :-
    bus_op(heuristica, H),
    bus_mejor_tarea(Ts, [T|Ts], H, T, E),
    E = tarea(_,_,Pos), bus_quita_pos([T|Ts], Pos, R).
bus_mejor_tarea([], _, _, E, E).
bus_mejor_tarea([T|Ts], Todos, H, Actual, E) :-
    bus_clave(T, Todos, H, KT), bus_clave(Actual, Todos, H, KA),
    (KT @< KA -> Siguiente = T ; Siguiente = Actual),
    bus_mejor_tarea(Ts, Todos, H, Siguiente, E).
bus_clave(tarea(_,_,I), _, original, clave(I,0,I)).
bus_clave(tarea(_,D,I), _, mrv, clave(N,0,I)) :- length(D,N).
bus_clave(tarea(_,D,I), _, ff, clave(N,0,I)) :- length(D,N).
bus_clave(T, Todos, ffc, clave(N,Neg,I)) :-
    T = tarea(_,D,I), length(D,N), bus_grado(T,Todos,G), Neg is -G.
bus_clave(T, Todos, grado, clave(Neg,N,I)) :-
    T = tarea(_,D,I), length(D,N), bus_grado(T,Todos,G), Neg is -G.
bus_clave(tarea(sesion(C,G,_),D,I), _, demanda, clave(Neg,N,I)) :-
    grupo(C,G,_,Inscritos,Semanal,Dur,_),
    Neg is -(Inscritos * Semanal * Dur), length(D,N).
bus_grado(_, [], 0).
bus_grado(T, [U|Us], Grado) :-
    T = tarea(_,D,I), U = tarea(_,D2,J),
    bus_grado(T, Us, G),
    ( I \= J, bus_dominios_conflicto(D,D2) -> Grado is G + 1 ; Grado = G ).
bus_dominios_conflicto(D1,D2) :-
    member(A,D1), member(B,D2), \+ compatible_asignaciones(A,B), !.

% LCV ordena por numero de valores que perderian los vecinos, desempate estable.
bus_valores(D, _, D) :- bus_op(valor, original), !.
bus_valores(D, Tareas, Valores) :-
    bus_puntua_valores(D,Tareas,Pares), keysort(Pares,Ordenados),
    bus_sin_claves(Ordenados,Valores).
bus_puntua_valores([], _, []).
bus_puntua_valores([A|As], Ts, [N-A|Ps]) :-
    bus_impacto_tareas(A,Ts,N), bus_puntua_valores(As,Ts,Ps).
bus_impacto_tareas(_, [], 0).
bus_impacto_tareas(A, [tarea(_,D,_)|Ts], N) :-
    bus_impacto_dominio(A,D,K), bus_impacto_tareas(A,Ts,M), N is K + M.
bus_impacto_dominio(_, [], 0).
bus_impacto_dominio(A, [B|Bs], N) :-
    bus_impacto_dominio(A,Bs,M),
    (compatible_asignaciones(A,B) -> N = M ; N is M + 1).
bus_sin_claves([], []).
bus_sin_claves([_-A|Ps], [A|As]) :- bus_sin_claves(Ps,As).

% Branch and bound: preferencias definitivamente imposibles. Los huecos
% parciales NO son una cota: una sesion posterior puede rellenarlos.
bus_poda(Asignadas, Tareas) :-
    bus_op(optimizar, si), bus_mejor(_, Mejor),
    findall(pref(C,G,D,F,W), restriccion(prefiere(C,G,D,F,W),_), Prefs),
    bus_cota_preferencias(Prefs, Asignadas, Tareas, Cota), Cota >= Mejor.
bus_cota_preferencias([], _, _, 0).
bus_cota_preferencias([pref(C,G,D,F,W)|Ps], As, Ts, Cota) :-
    bus_cota_preferencias(Ps, As, Ts, Resto),
    ( bus_preferencia_posible(C,G,D,F,As,Ts) -> Cota = Resto
    ; Cota is Resto + W ).
bus_preferencia_posible(C,G,D,F,As,_) :- member(asig(C,G,_,_,D,F,_),As), !.
bus_preferencia_posible(C,G,D,F,_,Ts) :-
    member(tarea(sesion(C,G,_),Dom,_),Ts), member(asig(C,G,_,_,D,F,_),Dom), !.

bus_registra(Asignadas) :-
    sesiones(Ss), bus_ordena_horario(Ss, Asignadas, H),
    verifica(H), costo(H, Coste),
    ( bus_mejor(_, Actual), Actual =< Coste -> true
    ; retractall(bus_mejor(_,_)), assertz(bus_mejor(H,Coste)) ),
    ( bus_op(optimizar,no) -> assertz(bus_corte(encontrada))
    ; Coste =:= 0 -> assertz(bus_corte(optima))
    ; true ).
bus_ordena_horario([], _, []).
bus_ordena_horario([sesion(C,G,I)|Ss], As, [A|Hs]) :-
    A = asig(C,G,I,_,_,_,_), member(A, As), !,
    bus_ordena_horario(Ss, As, Hs).

% Dos simetrias opcionales que conservan tambien el coste:
% 1. sesiones indistinguibles de un grupo en orden cronologico;
% 2. primera utilizacion GLOBAL de aulas intercambiables en orden de lectura.
% Un aula nombrada por aula_fija queda excluida de la segunda simetria.
bus_simetria(_) :- bus_op(simetria,no), !.
bus_simetria(As) :-
    bus_sesiones_ordenadas(As),
    sesiones(Ss), bus_prefijo_asignado(Ss,As,Prefijo),
    bus_primera_aula(Prefijo,[]).
bus_sesiones_ordenadas([]).
bus_sesiones_ordenadas([A|As]) :-
    bus_orden_con_lista(A,As), bus_sesiones_ordenadas(As).
bus_orden_con_lista(_, []).
bus_orden_con_lista(asig(C,G,I,A,D,F,L), [asig(C2,G2,J,_,D2,F2,_)|As]) :-
    ( C == C2, G == G2 ->
        bus_tiempo(D,F,T), bus_tiempo(D2,F2,T2),
        (I < J -> T < T2 ; T > T2)
    ; true ),
    bus_orden_con_lista(asig(C,G,I,A,D,F,L),As).
bus_prefijo_asignado([], _, []).
bus_prefijo_asignado([sesion(C,G,I)|Ss], As, R) :-
    ( member(asig(C,G,I,A,D,F,L),As) ->
        R = [asig(C,G,I,A,D,F,L)|Rs], bus_prefijo_asignado(Ss,As,Rs)
    ; R = [] ).
bus_primera_aula([], _).
bus_primera_aula([asig(_,_,_,A,_,_,_)|As], Vistas) :-
    ( member(A,Vistas) -> Nuevas = Vistas
    ; bus_predecesoras_vistas(A,Vistas), Nuevas = [A|Vistas] ),
    bus_primera_aula(As,Nuevas).
bus_predecesoras_vistas(A, _) :- restriccion(aula_fija(_,_,A),_), !.
bus_predecesoras_vistas(A, Vistas) :-
    aula(A,Cap,Tipo), findall(B,aula(B,_,_),Aulas),
    bus_aulas_anteriores(Aulas,A,Cap,Tipo,Vistas).
bus_aulas_anteriores([A|_], A, _, _, _) :- !.
bus_aulas_anteriores([B|Bs], A, Cap, Tipo, Vistas) :-
    ( aula(B,Cap,Tipo), \+ restriccion(aula_fija(_,_,B),_) -> member(B,Vistas) ; true ),
    bus_aulas_anteriores(Bs,A,Cap,Tipo,Vistas).

% Diagnostico acotado, separado de las metricas de la ejecucion principal.
% La causa es la primera restriccion de un prefijo INSAT probado, siempre que
% todos los prefijos anteriores hayan sido SAT. No afirma un nucleo minimo.
% El impacto mide valores eliminados en la propagacion inicial al incorporar
% cada restriccion individualmente a las reglas obligatorias del modelo.
diagnosticar_restricciones(diagnostico(Causa, Impactos)) :-
    bus_diag_guarda(Estado),
    ( catch(bus_diag_calcula(Estado,Causa,Impactos),Error,
            (bus_diag_restaura(Estado),throw(Error))) ->
        bus_diag_restaura(Estado)
    ; bus_diag_restaura(Estado), fail ).

bus_diag_guarda(estado(Rs,Os,Cs,Ms,Fs)) :-
    findall(R-L,restriccion(R,L),Rs),
    findall(K-V,opcion(K,V),Os),
    findall(K-N,bus_contador(K,N),Cs),
    findall(H-C,bus_mejor(H,C),Ms),
    findall(F,bus_corte(F),Fs).
bus_diag_restaura(estado(Rs,Os,Cs,Ms,Fs)) :-
    bus_diag_pon_restricciones(Rs),
    retractall(opcion(_,_)),bus_diag_pon_opciones(Os),
    retractall(bus_contador(_,_)),bus_diag_pon_contadores(Cs),
    retractall(bus_mejor(_,_)),bus_diag_pon_mejores(Ms),
    retractall(bus_corte(_)),bus_diag_pon_cortes(Fs).
bus_diag_pon_restricciones(Rs) :-
    retractall(restriccion(_,_)),bus_diag_anade_restricciones(Rs).
bus_diag_anade_restricciones([]).
bus_diag_anade_restricciones([R-L|Rs]) :-
    assertz(restriccion(R,L)),bus_diag_anade_restricciones(Rs).
bus_diag_pon_opciones([]).
bus_diag_pon_opciones([K-V|Os]) :- assertz(opcion(K,V)),bus_diag_pon_opciones(Os).
bus_diag_pon_contadores([]).
bus_diag_pon_contadores([K-N|Cs]) :- assertz(bus_contador(K,N)),bus_diag_pon_contadores(Cs).
bus_diag_pon_mejores([]).
bus_diag_pon_mejores([H-C|Ms]) :- assertz(bus_mejor(H,C)),bus_diag_pon_mejores(Ms).
bus_diag_pon_cortes([]).
bus_diag_pon_cortes([F|Fs]) :- assertz(bus_corte(F)),bus_diag_pon_cortes(Fs).

bus_diag_calcula(estado(Rs,_,_,_,_), Causa, Impactos) :-
    bus_op(limite,Original), Limite is min(Original,10000),
    retractall(opcion(_,_)),
    bus_diag_pon_opciones([heuristica-ff,valor-original,anticipada-si,
                          optimizar-no,limite-Limite,simetria-no]),
    bus_diag_particion(Rs,Duras,Blandas),
    bus_diag_pon_restricciones(Blandas),
    ejecutar_busqueda(clpfd,_,Estado,_),
    ( Estado == sin_solucion -> Causa = base_inviable
    ; Estado == limite -> Causa = indeterminado(base,Limite)
    ; bus_diag_prefijos(Duras,Limite,Causa) ),
    bus_diag_pon_restricciones(Blandas),
    bus_diag_total(Base),
    bus_diag_impactos(Duras,Blandas,Base,Impactos).
bus_diag_particion([],[],[]).
bus_diag_particion([R-L|Rs],Duras,Blandas) :-
    ( bus_diag_dura(R) -> Duras = [R-L|Ds], Blandas = Bs
    ; Duras = Ds, Blandas = [R-L|Bs] ),
    bus_diag_particion(Rs,Ds,Bs).
bus_diag_dura(aula_fija(_,_,_)).
bus_diag_dura(prohibida(_,_,_,_)).
bus_diag_dura(excluyentes(_,_,_,_)).

bus_diag_prefijos([],_,sin_prefijo_inviable).
bus_diag_prefijos([R-L|Rs],Limite,Causa) :-
    assertz(restriccion(R,L)),
    ejecutar_busqueda(clpfd,_,Estado,_),
    ( Estado == sin_solucion -> Causa = primera_inviable(L,R)
    ; Estado == limite -> Causa = indeterminado(prefijo(L,R),Limite)
    ; bus_diag_prefijos(Rs,Limite,Causa) ).

bus_diag_total(Total) :-
    ( inconsistencias([]), sesiones(Ss), bus_tareas(Ss,1,Ts),
      bus_fd_prepara(Ts),bus_fd_crea(Ts,Fs),
      bus_fd_restricciones(Fs),bus_fd_grupos(Fs,Fs),
      bus_diag_suma_dominios(Fs,N) -> Total = N
    ; Total = 0 ).
bus_diag_suma_dominios([],0).
bus_diag_suma_dominios([fd(_,_,V,_,_,_,_)|Fs],N) :-
    fd_dom(V,Ds),length(Ds,K),bus_diag_suma_dominios(Fs,M),N is K+M.
bus_diag_impactos([],_,_,[]).
bus_diag_impactos([R-L|Rs],Blandas,Base,[impacto(L,R,Eliminados,Base)|Is]) :-
    bus_diag_pon_restricciones([R-L|Blandas]),bus_diag_total(Actual),
    Eliminados is max(0,Base-Actual),
    bus_diag_impactos(Rs,Blandas,Base,Is).

