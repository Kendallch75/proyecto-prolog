:- dynamic(opcion/2).

opciones_defecto :-
    retractall(opcion(_,_)),
    assertz(opcion(heuristica,original)), assertz(opcion(valor,original)),
    assertz(opcion(anticipada,no)), assertz(opcion(optimizar,no)),
    assertz(opcion(limite,500000)), assertz(opcion(simetria,si)),
    assertz(opcion(aulas,no)), assertz(opcion(prolog,ninguno)), assertz(opcion(csv,ninguno)).
cli_opcion(K,V) :- retractall(opcion(K,_)),assertz(opcion(K,V)).

cli :-
    catch((argument_list(Args),cli_argumentos(Args,Codigo)),E,
          (format(user_error,'Error: ~q~n',[E]),Codigo=1)),
    halt(Codigo).

cli_argumentos(['--help'],0) :- !, ayuda.
cli_argumentos(['--ayuda'],0) :- !, ayuda.
cli_argumentos(Args,Codigo) :-
    cli_quitar_motor(Args,Limpios),
    (Limpios=[Entrada,Salida,E|Opciones] ->
       opciones_defecto,
       (cli_estrategia(E),cli_opciones(Opciones),cli_rutas(Entrada,Salida) ->
          ejecutar(Entrada,Salida,E,Codigo)
       ; format(user_error,'Argumentos invalidos. Use --ayuda.~n',[]),Codigo=64)
    ; ayuda,Codigo=64).
% GNU Prolog conserva en argument_list/1 los argumentos posteriores a --.
% Se acepta tambien su lista completa cuando se invoca desde otra envoltura.
cli_quitar_motor(Args,L) :- append(_,['--'|L],Args), !.
cli_quitar_motor(Args,Args).
cli_estrategia(bt).
cli_estrategia(clpfd).
cli_opciones([]).
cli_opciones([O|Os]) :- cli_opcion_arg(O),cli_opciones(Os).
cli_opcion_arg('--optimizar') :- cli_opcion(optimizar,si).
cli_opcion_arg('--anticipada') :- cli_opcion(anticipada,si).
cli_opcion_arg('--sin-anticipada') :- cli_opcion(anticipada,no).
cli_opcion_arg('--aulas') :- cli_opcion(aulas,si).
cli_opcion_arg('--sin-simetria') :- cli_opcion(simetria,no).
cli_opcion_arg(O) :- cli_valor(O,'--heuristica=',H),
    mod_miembro(H,[original,mrv,ff,ffc,grado,demanda]),
    cli_opcion(heuristica,H),(H==original -> true;cli_opcion(anticipada,si)).
cli_opcion_arg(O) :- cli_valor(O,'--valor=',V),mod_miembro(V,[original,lcv]),cli_opcion(valor,V).
cli_opcion_arg(O) :- cli_valor(O,'--limite=',A),atom_codes(A,Cs),Cs\=[],
    cli_digitos(Cs),number_codes(N,Cs),cli_opcion(limite,N).
cli_opcion_arg(O) :- cli_valor(O,'--prolog=',F),F\=='',cli_opcion(prolog,F).
cli_opcion_arg(O) :- cli_valor(O,'--csv=',F),F\=='',cli_opcion(csv,F).
cli_valor(A,P,V) :- atom_codes(A,Cs),atom_codes(P,Ps),append(Ps,Vs,Cs),atom_codes(V,Vs).
cli_digitos([]).
cli_digitos([C|Cs]) :- C>=48,C=<57,cli_digitos(Cs).
cli_rutas(E,S) :-
    opcion(prolog,P),opcion(csv,C),
    cli_rutas_activas([E,S,P,C],Activas),
    cli_absolutas(Activas,Absolutas),sort(Absolutas,Unicas),
    length(Absolutas,N),length(Unicas,N).
cli_rutas_activas([],[]).
cli_rutas_activas([ninguno|Xs],Ys) :- !,cli_rutas_activas(Xs,Ys).
cli_rutas_activas([X|Xs],[X|Ys]) :- cli_rutas_activas(Xs,Ys).
cli_absolutas([],[]).
cli_absolutas([X|Xs],[A|As]) :- absolute_file_name(X,A),cli_absolutas(Xs,As).

main(Entrada,Salida,Estrategia) :-
    opciones_defecto,cli_estrategia(Estrategia),cli_rutas(Entrada,Salida),
    ejecutar(Entrada,Salida,Estrategia,Codigo),Codigo=0.

main(Entrada,Salida,Estrategia,Opciones) :-
    opciones_defecto,cli_estrategia(Estrategia),cli_opciones(Opciones),
    cli_rutas(Entrada,Salida),ejecutar(Entrada,Salida,Estrategia,Codigo),Codigo=0.

ejecutar(Entrada,Salida,E,Codigo) :-
    statistics(runtime,[CPU0,_]),statistics(real_time,[Pared0,_]),
    (cargar_instancia(Entrada) ->
       espacio_busqueda(NS,Log),inconsistencias(Razones),
       (Razones=[] ->
          ejecutar_busqueda(E,H,Estado,Opt),metricas_busqueda(Nodos,Retrocesos),
          (H\=[] ->
             (verifica(H)->true;throw(error(verificacion_independiente_fallo,H)))
          ; Estado==solucion ->
             (verifica(H)->true;throw(error(verificacion_independiente_fallo,H)))
          ; true),
          (Estado==limite -> BaseCodigo=3;BaseCodigo=0),
          DiagBase=[]
       ; H=[],Estado=sin_solucion,Opt=no,Nodos=0,Retrocesos=0,
         DiagBase=Razones,BaseCodigo=2)
    ; H=[],Estado=invalida,Opt=no,Nodos=0,Retrocesos=0,NS=0,Log=0,
      findall(error(L,M),error_instancia(L,M),DiagBase),BaseCodigo=2),
    (Estado==sin_solucion -> diagnosticar_restricciones(Diagnostico),append(DiagBase,[Diagnostico],Diag)
    ; Diag=DiagBase),
    statistics(runtime,[CPU1,_]),statistics(real_time,[Pared1,_]),
    CPU is (CPU1-CPU0)/1000,Pared is (Pared1-Pared0)/1000,
    M=metricas(Nodos,Retrocesos,CPU,Pared,NS,Log),
    catch((escribir_resultados(Salida,Entrada,E,Estado,Opt,H,M,Diag),Codigo=BaseCodigo),
          Error,(format(user_error,'No se pudo escribir la salida: ~q~n',[Error]),Codigo=4)),
    (Codigo=:=4 -> true;texto_estado(Estado,Texto),format('~a: ~a~n',[Texto,Salida])),
    (Diag=[] -> true;format('Diagnostico: ~q~n',[Diag])).

ayuda :-
    write('Uso: ./horarios.sh entrada.dat salida.txt bt|clpfd [opciones]'),nl,
    write('  --heuristica=original|mrv|ff|ffc|grado|demanda'),nl,
    write('  --anticipada | --sin-anticipada    --valor=original|lcv'),nl,
    write('  --optimizar    --limite=N (defecto 500000; 0: ningun nodo)'),nl,
    write('  --aulas    --prolog=salida.pl    --csv=salida.csv'),nl,
    write('  --sin-simetria    --ayuda'),nl,
    write('Codigos: 0 resuelto/sin solucion exhaustiva; 2 instancia invalida/inconsistente;'),nl,
    write('         3 limite; 4 error de escritura; 64 argumentos invalidos; 1 error inesperado.'),nl.
