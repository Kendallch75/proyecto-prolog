% Informes de texto, hechos Prolog consultables y extension CSV.
texto_estado(solucion,'SOLUCION ENCONTRADA').
texto_estado(sin_solucion,'SIN SOLUCION').
texto_estado(limite,'LIMITE ALCANZADO').
texto_estado(invalida,'INSTANCIA INVALIDA').

escribir_resultados(Archivo,Inst,E,Estado,Opt,H,M,Diag) :-
    sal_ordenar(H,Ordenado),
    sal_archivo(Archivo,sal_informe(Inst,E,Estado,Opt,Ordenado,M,Diag)),
    opcion(prolog,P),(P==ninguno -> true;sal_archivo(P,sal_hechos(Ordenado))),
    opcion(csv,C),(C==ninguno -> true;sal_archivo(C,sal_csv(Ordenado))).
sal_archivo(Archivo,Goal) :-
    open(Archivo,write,S),
    catch((call(Goal,S),close(S)),E,(catch(close(S),_,true),throw(E))).

sal_ordenar(H,S) :- findall(k(C,G,DI,F,I)-A,
    (mod_miembro(A,H),A=asig(C,G,I,_,D,F,_),config(dias,Ds),sal_indice(D,Ds,1,DI)),Pairs),
    keysort(Pairs,Orden),sal_valores(Orden,S).
sal_indice(X,[X|_],N,N) :- !.
sal_indice(X,[_|Xs],N,I) :- N1 is N+1,sal_indice(X,Xs,N1,I).
sal_valores([],[]).
sal_valores([_-V|Xs],[V|Vs]) :- sal_valores(Xs,Vs).
sal_linea(S) :- format(S,'================================================================~n',[]).

sal_informe(Inst,E,Estado,Opt,H,M,Diag,S) :-
    sal_linea(S),format(S,'       ASIGNACION DE HORARIOS UNIVERSITARIOS~n',[]),sal_linea(S),
    texto_estado(Estado,Texto),opcion(heuristica,Heur),
    format(S,'Instancia : ~a~nEstrategia : ~a (~a)~nEstado : ~a~n',[Inst,E,Heur,Texto]),
    date_time(dt(Y,Mes,D,Hora,Min,Seg)),
    format(S,'Fecha : ~d-',[Y]),sal_dos(Mes,S),put_char(S,'-'),sal_dos(D,S),
    put_char(S,' '),sal_dos(Hora,S),put_char(S,':'),sal_dos(Min,S),put_char(S,':'),sal_dos(Seg,S),nl(S),
    format(S,'Optimo demostrado : ~a~n',[Opt]),sal_linea(S),
    format(S,'DETALLE DE ASIGNACIONES~n# | Curso | Grupo | Profesor(es) | Aula | Dia | Franjas~n',[]),
    sal_detalle(H,1,S),(H=[] -> format(S,'Sin sesiones asignadas.~n',[]);true),sal_linea(S),
    (Estado==invalida -> true;sal_rejillas(H,S)),sal_linea(S),
    ((Estado==solucion;H\=[]) -> sal_resumen(H,Estado,Opt,M,S)
    ;sal_diagnostico(Diag,Estado,M,S)),
    sal_linea(S),format(S,'METRICAS DE EJECUCION~n',[]),sal_metricas(M,S).

sal_profesores(C,G,Ps) :- findall(P,imparte(C,G,P),P0),sort(P0,Ps).
sal_detalle([],_,_).
sal_detalle([asig(C,G,_,A,D,F,L)|Xs],N,S) :-
    sal_profesores(C,G,Ps),Fin is F+L-1,
    format(S,'~d | ~a | ~a | ~q | ~a | ~a | ~d-~d~n',[N,C,G,Ps,A,D,F,Fin]),
    N1 is N+1,sal_detalle(Xs,N1,S).

sal_rejillas(H,S) :-
    findall(grupo(C,G),grupo(C,G,_,_,_,_,_),Gs),sal_tablas(Gs,H,S),
    findall(profesor(P),profesor(P,_,_,_),Ps),sal_tablas(Ps,H,S),
    (opcion(aulas,si)->findall(aula(A),aula(A,_,_),As),sal_tablas(As,H,S);true).
sal_tablas([],_,_).
sal_tablas([Entidad|Xs],H,S) :-
    nl(S),sal_titulo_entidad(Entidad,S),config(dias,Ds),
    format(S,'Franja | Hora',[]),sal_cabecera(Ds,S),nl(S),
    config(franjas,F),sal_filas(1,F,Ds,Entidad,H,S),sal_tablas(Xs,H,S).
sal_titulo_entidad(grupo(C,G),S) :- format(S,'HORARIO POR GRUPO: ~a ~a~n',[C,G]).
sal_titulo_entidad(profesor(P),S) :- format(S,'HORARIO POR PROFESOR: ~a~n',[P]).
sal_titulo_entidad(aula(A),S) :- format(S,'HORARIO POR AULA: ~a~n',[A]).
sal_cabecera([],_).
sal_cabecera([D|Ds],S) :- format(S,' | ~a',[D]),sal_cabecera(Ds,S).
sal_filas(F,Max,_,_,_,_) :- F>Max,!.
sal_filas(F,Max,Ds,E,H,S) :-
    config(inicio,Inicio),config(duracion_franja,Dur),T is Inicio+(F-1)*Dur,T2 is T+Dur,
    format(S,'~d | ',[F]),sal_hora(T,S),put_char(S,'-'),sal_hora(T2,S),
    sal_celdas(Ds,F,E,H,S),nl(S),F1 is F+1,sal_filas(F1,Max,Ds,E,H,S).
sal_hora(T,S) :- HH is T//60,MM is T mod 60,sal_dos(HH,S),put_char(S,':'),sal_dos(MM,S).
sal_dos(N,S) :- (N<10->put_char(S,'0');true),write(S,N).
sal_celdas([],_,_,_,_).
sal_celdas([D|Ds],F,E,H,S) :-
    (sal_celda(E,H,D,F,C,G)->format(S,' | ~a/~a',[C,G]);format(S,' | --',[])),
    sal_celdas(Ds,F,E,H,S).
sal_celda(E,H,D,F,C,G) :- mod_miembro(asig(C,G,_,A,D,Ini,L),H),
    F>=Ini,F<Ini+L,sal_entidad(E,C,G,A),!.
sal_entidad(grupo(C,G),C,G,_).
sal_entidad(profesor(P),C,G,_) :- imparte(C,G,P).
sal_entidad(aula(A),_,_,A).

sal_resumen(H,Estado,Opt,_,S) :-
    mod_longitud(H,N),findall(L,mod_miembro(asig(_,_,_,_,_,_,L),H),Ls),mod_suma(Ls,Franjas),
    findall(K,(grupo(C,G,_,_,_,_,_),huecos_grupo(H,C,G,K)),Ks),mod_suma(Ks,HG),
    findall(K,(profesor(P,_,_,_),huecos_profesor(H,P,K)),KPs),mod_suma(KPs,HP),costo(H,Costo),
    format(S,'RESUMEN~nSesiones programadas ............ ~d~nFranjas-sesion ocupadas ......... ~d~n',[N,Franjas]),
    format(S,'Huecos de grupo ................. ~d~nHuecos de profesor .............. ~d~n',[HG,HP]),
    format(S,'Costo de restricciones blandas .. ~d~n',[Costo]),
    format(S,'Verificacion independiente ...... aprobada~nOptimo demostrado ............... ~a~n',[Opt]),
    (Estado==limite -> format(S,'Estado final .................... limite; mejor horario completo conservado~n',[])
    ;format(S,'Estado final .................... solucion valida~n',[])).
sal_metricas(metricas(N,B,CPU,Pared,NS,Log),S) :-
    format(S,'Sesiones a programar ............ ~d~nEspacio ingenuo (log10) ......... ~6f~n',[NS,Log]),
    format(S,'Nodos explorados ................ ~d~nRetrocesos (backtracks) ......... ~d~n',[N,B]),
    format(S,'Tiempo de CPU (s) ............... ~6f~nTiempo de pared (s) ............. ~6f~n',[CPU,Pared]),
    (CPU>0->R is N/CPU,format(S,'Nodos por segundo ............... ~2f~n',[R])
    ;format(S,'Nodos por segundo ............... no medible (< 1 ms)~n',[])).
sal_diagnostico(Diag,Estado,metricas(_,_,_,_,NS,_),S) :-
    format(S,'DIAGNOSTICO~nSesiones a programar: ~d~n',[NS]),sal_razones(Diag,S),
    (Estado==invalida -> true
    ; config(dias,Ds),mod_longitud(Ds,ND),config(franjas,F),
      findall(A,aula(A,_,_),As),mod_longitud(As,NA),Disp is ND*F*NA,
      format(S,'Franjas-aula disponibles: ~d (~d dias x ~d franjas x ~d aulas)~n',[Disp,ND,F,NA]),
      sal_mayor_demanda(S),sal_restricciones(S),
      (Estado==limite -> format(S,'No se ha demostrado insatisfacibilidad: se agoto el limite.~n',[])
      ;format(S,'No existe horario que satisfaga conjuntamente las restricciones duras.~n',[]))).
sal_razones([],_).
sal_razones([diagnostico(Causa,Impactos)|Xs],S) :- !,
    sal_causa(Causa,S),sal_impactos(Impactos,S),sal_razones(Xs,S).
sal_razones([error(L,M)|Xs],S) :- !,format(S,'Linea ~d: ~a~n',[L,M]),sal_razones(Xs,S).
sal_razones([X|Xs],S) :- format(S,'Inconsistencia: ~q~n',[X]),sal_razones(Xs,S).
sal_mayor_demanda(S) :-
    findall(N-grupo(C,G),(grupo(C,G,_,_,K,L,_),N is K*L),Gs),
    findall(N-profesor(P),(profesor(P,_,_,_),demanda_profesor(P,N)),Ps),
    append(Gs,Ps,T),keysort(T,Orden),
    (Orden=[] -> true;mod_ultimo(Orden,N-E),format(S,'Mayor demanda: ~q, ~d franjas semanales.~n',[E,N])).
sal_restricciones(S) :-
    findall(L-R,(restriccion(R,L),sal_dura(R)),Rs),
    (Rs=[] -> format(S,'No hay restricciones duras declaradas; revisar capacidad y recursos compartidos.~n',[])
    ;format(S,'Restricciones duras declaradas implicadas (no es un nucleo minimo):~n',[]),sal_lista_restricciones(Rs,S)).
sal_dura(aula_fija(_,_,_)).
sal_dura(prohibida(_,_,_,_)).
sal_dura(excluyentes(_,_,_,_)).
sal_lista_restricciones([],_).
sal_lista_restricciones([L-R|Rs],S) :- format(S,'  Linea ~d: ~q~n',[L,R]),sal_lista_restricciones(Rs,S).

% Profesor es un atomo con un docente o una lista con varios (codocencia).
sal_hechos([],_).
sal_hechos([asig(C,G,_,A,D,F,L)|Xs],S) :-
    sal_profesores(C,G,Ps),(Ps=[Unico]->P=Unico;P=Ps),
    writeq(S,asignacion(C,G,P,A,D,F,L)),write(S,'.'),nl(S),sal_hechos(Xs,S).
sal_csv(H,S) :- format(S,'curso,grupo,sesion,profesores,aula,dia,inicio,duracion~n',[]),sal_csv_filas(H,S).
sal_csv_filas([],_).
sal_csv_filas([asig(C,G,I,A,D,F,L)|Xs],S) :-
    sal_profesores(C,G,Ps),sal_unir(Ps,'|',Profes),
    sal_csv_campo(C,S),put_char(S,','),sal_csv_campo(G,S),format(S,',~d,',[I]),
    sal_csv_campo(Profes,S),put_char(S,','),sal_csv_campo(A,S),put_char(S,','),sal_csv_campo(D,S),
    format(S,',~d,~d~n',[F,L]),sal_csv_filas(Xs,S).
sal_unir([],_,'').
sal_unir([X],_,X) :- !.
sal_unir([X|Xs],Sep,A) :- sal_unir(Xs,Sep,R),atom_concat(X,Sep,T),atom_concat(T,R,A).
sal_csv_campo(A,S) :- put_char(S,'"'),atom_codes(A,Cs),sal_csv_escape(Cs,S),put_char(S,'"').
sal_csv_escape([],_).
sal_csv_escape([34|Cs],S) :- !,put_char(S,'"'),put_char(S,'"'),sal_csv_escape(Cs,S).
sal_csv_escape([C|Cs],S) :- put_code(S,C),sal_csv_escape(Cs,S).

% Causa demostrada por prefijos, conservando las metricas de la busqueda original.
sal_causa(base_inviable,S) :-
    format(S,'La base ya es imposible sin las restricciones duras declaradas.~n',[]).
sal_causa(primera_inviable(L,R),S) :-
    format(S,'Primera restriccion que vuelve imposible el prefijo (comprobado):~n  Linea ~d: ~q~n',[L,R]).
sal_causa(indeterminado(P,L),S) :-
    format(S,'Diagnostico causal indeterminado: ~q alcanzo el limite de ~d nodos.~n',[P,L]).
sal_causa(sin_prefijo_inviable,S) :-
    format(S,'No se identifico un prefijo imposible en el diagnostico.~n',[]).
sal_impactos([],S) :- format(S,'Sin restricciones duras declaradas para comparar.~n',[]).
sal_impactos(Is,S) :- Is=[_|_],
    findall(N-I,(mod_miembro(I,Is),I=impacto(_,_,N,_)),Ps),keysort(Ps,Orden),
    mod_ultimo(Orden,Max-impacto(L,R,_,Base)),
    (Max>0 -> format(S,'Mayor poda individual en raiz: linea ~d, ~q (~d de ~d valores eliminados).~n',[L,R,Max,Base])
    ;format(S,'Las restricciones individuales no podan valores en la raiz; el conflicto es conjunto.~n',[])).
