% Pruebas de regresion GNU Prolog. Ejecutar desde la raiz del proyecto:
% gprolog --consult-file horarios.pl --consult-file tests/pruebas.pl --entry-goal pruebas
:- discontiguous(t_caso/2).
:- dynamic(t_correctas/1).
:- dynamic(t_fallidas/1).

pruebas :-
    retractall(t_correctas(_)), retractall(t_fallidas(_)),
    assertz(t_correctas(0)), assertz(t_fallidas(0)),
    (t_caso(Nombre,Objetivo), t_ejecuta(Nombre,Objetivo), fail ; true),
    t_correctas(Bien), t_fallidas(Mal),
    nl, write('RESULTADO: '), write(Bien), write(' correctas, '),
    write(Mal), write(' fallidas.'), nl,
    (Mal=:=0 -> halt(0) ; halt(1)).

t_ejecuta(Nombre,Objetivo) :-
    (catch(call(Objetivo),Error,(write('  Excepcion: '),write(Error),nl,fail)) ->
       retract(t_correctas(N)), M is N+1, assertz(t_correctas(M)), write('OK   ')
    ;  retract(t_fallidas(N)), M is N+1, assertz(t_fallidas(M)), write('FALLO ')),
    write(Nombre), nl.

t_opcion(K,V) :- retractall(opcion(K,_)),assertz(opcion(K,V)).
t_opciones :-
    t_opcion(heuristica,original), t_opcion(valor,original),
    t_opcion(anticipada,si), t_opcion(optimizar,no),
    t_opcion(limite,200000), t_opcion(simetria,si).
t_carga(F) :- cargar_instancia(F), t_opciones, valida([]).
t_tamano(F,N) :- t_carga(F), sesiones(S), length(S,N).
t_miembro(X,[X|_]).
t_miembro(X,[_|Xs]) :- t_miembro(X,Xs).
t_pequeno([
    asig('MAT','G1',1,'A-1','L',1,1),
    asig('MAT','G1',2,'A-1','L',2,1),
    asig('LAB','G1',1,'LAB-1','M',1,2)]).
t_blandas([
    asig('C','G',1,'A','L',1,1),
    asig('C','G',2,'A','L',4,1)]).

t_caso('campus: las diez sesiones del PDF',
    t_tamano('instancias/campus-central.dat',10)).
t_caso('campus: dieciocho franjas-sesion reales',
    (t_carga('instancias/campus-central.dat'),
     findall(T,(grupo(_,_,_,_,N,D,_),T is N*D),Ts),mod_suma(Ts,18))).
t_caso('pequena: tres sesiones',t_tamano('instancias/pequena.dat',3)).
t_caso('escala: veinte sesiones',t_tamano('instancias/escala-20.dat',20)).
t_caso('escala: cuarenta sesiones',t_tamano('instancias/escala-40.dat',40)).
t_caso('escala: ochenta sesiones',t_tamano('instancias/escala-80.dat',80)).
t_caso('parser: secciones reordenadas y campos recortados',
    (t_carga('instancias/semantica.dat'),grupo('T','G',_,25,1,2,teoria),
     findall(P,imparte('T','G',P),Ps),length(Ps,2))).
t_caso('parser: CRLF y ultima linea sin salto',
    t_tamano('instancias/formato-crlf.dat',1)).
t_caso('parser: acumula errores con numero de linea',
    (\+ cargar_instancia('instancias/invalida.dat'),
     findall(L,error_instancia(L,_),Ls),length(Ls,N),N>=8,
     \+ (t_miembro(L,Ls),\+ integer(L)))).
t_caso('parser: un archivo inexistente falla de forma controlada',
    (\+ cargar_instancia('instancias/archivo-no-existe.dat'),error_instancia(_,_))).
t_caso('parser: cargar reemplaza la instancia anterior',
    (t_carga('instancias/campus-central.dat'),t_carga('instancias/pequena.dat'),
     \+ grupo('IC-1802',_,_,_,_,_,_),sesiones(S),length(S,3))).

t_caso('dominio: capacidad y tipo de aula',
    (t_carga('instancias/semantica.dat'),dominio(sesion('T','G',1),D),
     length(D,2),t_miembro(asig('T','G',1,'A','L',1,2),D),
     t_miembro(asig('T','G',1,'X','L',1,2),D))).
t_caso('dominio: laboratorio admite aula mixta',
    (t_carga('instancias/semantica.dat'),dominio(sesion('B','G',1),D),
     t_miembro(asig('B','G',1,'B','M',1,1),D),
     t_miembro(asig('B','G',1,'X','M',1,1),D),
     \+ t_miembro(asig('B','G',1,'A',_,_,_),D))).
t_caso('dominio: requiere mixta admite los tres tipos',
    (t_carga('instancias/semantica.dat'),dominio(sesion('M','G',1),D),
     t_miembro(asig('M','G',1,'A','L',1,1),D),
     t_miembro(asig('M','G',1,'B','L',1,1),D),
     t_miembro(asig('M','G',1,'X','L',1,1),D))).
t_caso('dominio: disponibilidad de todos los docentes solo al inicio',
    (t_carga('instancias/semantica.dat'),dominio(sesion('T','G',1),D),
     t_miembro(asig('T','G',1,'A','L',1,2),D),
     \+ t_miembro(asig('T','G',1,_,'M',_,_),D))).
t_caso('dominio: aula fija y duracion no desbordan el dia',
    (t_carga('instancias/pequena.dat'),dominio(sesion('LAB','G1',1),D),
     length(D,4),\+ (t_miembro(asig(_,_,_,A,_,F,_),D),
                    (A\=='LAB-1';F>2)))).
t_caso('dominio: prohibida elimina toda sesion que cubre la franja',
    (t_carga('instancias/semantica.dat'),
     retractall(imparte('T','G','P2')),
     dominio(sesion('T','G',1),D),
     \+ t_miembro(asig('T','G',1,_,'M',1,2),D))).

t_caso('verifica: horario valido con duracion y co-docencia',
    (t_carga('instancias/pequena.dat'),t_pequeno(H),verifica(H))).
t_caso('verifica: rechaza sesion faltante',
    (t_carga('instancias/pequena.dat'),t_pequeno([_|H]),\+ verifica(H))).
t_caso('verifica: rechaza identidad de sesion duplicada',
    (t_carga('instancias/pequena.dat'),t_pequeno([X,_,Z]),\+ verifica([X,X,Z]))).
t_caso('verifica: rechaza aula con capacidad insuficiente',
    (t_carga('instancias/pequena.dat'),t_pequeno(H),
     retract(aula('A-1',_,teoria)),assertz(aula('A-1',24,teoria)),\+ verifica(H))).
t_caso('verifica: rechaza teoria en laboratorio incluso con capacidad',
    (t_carga('instancias/pequena.dat'),t_pequeno([_,Y,Z]),
     retract(grupo('MAT','G1',Nombre,_,N,D,teoria)),
     assertz(grupo('MAT','G1',Nombre,18,N,D,teoria)),
     \+ verifica([asig('MAT','G1',1,'LAB-1','L',1,1),Y,Z]))).
t_caso('verifica: rechaza otra aula aunque tenga tipo y capacidad correctos',
    (t_carga('instancias/pequena.dat'),t_pequeno([X,Y,_]),
     assertz(aula('LAB-2',20,laboratorio)),
     \+ verifica([X,Y,asig('LAB','G1',1,'LAB-2','M',1,2)]))).
t_caso('verifica: rechaza colision del mismo grupo',
    (t_carga('instancias/pequena.dat'),t_pequeno([X,_,Z]),
     \+ verifica([X,asig('MAT','G1',2,'A-1','L',1,1),Z]))).
t_caso('verifica: rechaza colision de profesor en aulas distintas',
    (t_carga('instancias/pequena.dat'),t_pequeno([X,Y,_]),
     \+ verifica([X,Y,asig('LAB','G1',1,'LAB-1','L',1,2)]))).
t_caso('verifica: rechaza colision de aula entre docentes distintos',
    (t_carga('instancias/semantica.dat'),
     \+ verifica([asig('T','G',1,'A','L',1,2),
                   asig('B','G',1,'B','M',1,1),
                   asig('M','G',1,'A','L',1,1)]))).
t_caso('verifica: rechaza grupos excluyentes en aulas distintas',
    (t_carga('instancias/semantica.dat'),
     \+ verifica([asig('T','G',1,'A','L',1,2),
                   asig('B','G',1,'B','M',1,1),
                   asig('M','G',1,'X','M',1,1)]))).
t_caso('verifica: rechaza franja prohibida',
    (t_carga('instancias/pequena.dat'),t_pequeno([X,_,Z]),
     \+ verifica([X,asig('MAT','G1',2,'A-1','M',3,1),Z]))).
t_caso('verifica: rechaza duracion que excede el dia',
    (t_carga('instancias/pequena.dat'),t_pequeno([X,Y,_]),
     \+ verifica([X,Y,asig('LAB','G1',1,'LAB-1','M',3,2)]))).
t_caso('verifica: rechaza disponibilidad de un codocente',
    (t_carga('instancias/semantica.dat'),
     \+ verifica([asig('T','G',1,'A','M',1,2),
                   asig('B','G',1,'B','L',1,1),
                   asig('M','G',1,'X','L',2,1)]))).
t_caso('verifica: rechaza exceso del maximo de profesor',
    (t_carga('instancias/pequena.dat'),
     retract(profesor('P-1',Nombre,_,Disp)),assertz(profesor('P-1',Nombre,3,Disp)),
     t_pequeno(H),\+ verifica(H))).

t_caso('costo: preferencia satisfecha y sin huecos',
    (t_carga('instancias/pequena.dat'),t_pequeno(H),costo(H,0))).
t_caso('costo: cuenta dos franjas vacias internas, no los extremos',
    (t_carga('instancias/blandas.dat'),t_blandas(H),verifica(H),costo(H,11))).
t_caso('costo: no cuenta huecos entre dias distintos',
    (t_carga('instancias/pequena.dat'),
     H=[asig('MAT','G1',1,'A-1','L',1,1),
        asig('MAT','G1',2,'A-1','M',2,1),
        asig('LAB','G1',1,'LAB-1','L',2,2)],verifica(H),costo(H,0))).
t_caso('costo: preferencia requiere inicio, no basta cubrir la franja',
    (t_carga('instancias/pequena.dat'),t_pequeno(H),
     assertz(restriccion(prefiere('LAB','G1','M',2,7),999)),costo(H,7))).

t_caso('bt: generacion y prueba sin verificacion anticipada',
    (t_carga('instancias/pequena.dat'),t_opcion(anticipada,no),
     ejecutar_busqueda(bt,H,solucion,_),verifica(H))).
t_caso('bt: MRV y valor menos restrictivo',
    (t_carga('instancias/pequena.dat'),t_opcion(heuristica,mrv),t_opcion(valor,lcv),
     ejecutar_busqueda(bt,H,solucion,_),verifica(H))).
t_caso('bt: seleccion por grado',
    (t_carga('instancias/pequena.dat'),t_opcion(heuristica,grado),
     ejecutar_busqueda(bt,H,solucion,_),verifica(H))).
t_caso('bt: seleccion por demanda',
    (t_carga('instancias/pequena.dat'),t_opcion(heuristica,demanda),
     ejecutar_busqueda(bt,H,solucion,_),verifica(H))).
t_caso('clpfd: first-fail devuelve horario verificado',
    (t_carga('instancias/pequena.dat'),t_opcion(heuristica,ff),
     ejecutar_busqueda(clpfd,H,solucion,_),verifica(H))).
t_caso('clpfd: ffc devuelve horario verificado',
    (t_carga('instancias/pequena.dat'),t_opcion(heuristica,ffc),
     ejecutar_busqueda(clpfd,H,solucion,_),verifica(H))).
t_caso('bt: optimizacion demuestra costo positivo minimo',
    (t_carga('instancias/blandas.dat'),t_opcion(optimizar,si),
     ejecutar_busqueda(bt,H,solucion,si),verifica(H),costo(H,11))).
t_caso('clpfd: optimizacion demuestra costo positivo minimo',
    (t_carga('instancias/blandas.dat'),t_opcion(optimizar,si),
     ejecutar_busqueda(clpfd,H,solucion,si),verifica(H),costo(H,11))).
t_caso('bt: conflicto global prueba ausencia de solucion',
    (t_carga('instancias/sin-solucion.dat'),
     inconsistencias([]),ejecutar_busqueda(bt,[],sin_solucion,_))).
t_caso('clpfd: conflicto global prueba ausencia de solucion',
    (t_carga('instancias/sin-solucion.dat'),
     inconsistencias([]),ejecutar_busqueda(clpfd,[],sin_solucion,_))).
t_caso('bt: limite de nodos no entrega horario parcial',
    (t_carga('instancias/pequena.dat'),t_opcion(limite,1),
     ejecutar_busqueda(bt,[],limite,no))).
t_caso('clpfd: limite de nodos no entrega horario parcial',
    (t_carga('instancias/pequena.dat'),t_opcion(limite,1),
     ejecutar_busqueda(clpfd,[],limite,no))).
t_caso('clpfd: instancia creciente de veinte sesiones',
    (t_carga('instancias/escala-20.dat'),t_opcion(heuristica,ff),
     ejecutar_busqueda(clpfd,H,solucion,_),length(H,20),verifica(H))).

% La envoltura se invoca de verdad: ninguna utilidad externa lee la instancia.
% system/2 devuelve el estado wait(2); la salida normal ocupa el byte alto.
t_comando(Args,Codigo) :-
    t_shell_args(Args,Texto),
    atom_concat(Texto,' > /tmp/horarios-pruebas-consola.log 2>&1',Cmd),
    system(Cmd,Estado), Codigo is Estado//256.
t_cli(Args,Codigo) :- t_comando([sh,'horarios.sh'|Args],Codigo).
t_shell_args([], '').
t_shell_args([X|Xs],A) :-
    atom_codes(X,Cs),t_shell_escape(Cs,Es),append([39|Es],[39,32],Qs),
    atom_codes(Q,Qs),t_shell_args(Xs,R),atom_concat(Q,R,A).
t_shell_escape([],[]).
t_shell_escape([39|Cs],[39,34,39,34,39|Es]) :- !,t_shell_escape(Cs,Es).
t_shell_escape([C|Cs],[C|Es]) :- t_shell_escape(Cs,Es).
t_lee_archivo(F,Cs) :- open(F,read,S),t_lee_codigos(S,Cs),close(S).
t_lee_codigos(S,Cs) :- get_code(S,C),(C=:= -1 -> Cs=[];Cs=[C|Xs],t_lee_codigos(S,Xs)).
t_contiene(F,A) :- t_lee_archivo(F,Cs),atom_codes(A,As),append(_,R,Cs),append(As,_,R),!.
t_copia(A,B) :- t_lee_archivo(A,Cs),open(B,write,S),t_escribe_codigos(Cs,S),close(S).
t_escribe_codigos([],_).
t_escribe_codigos([C|Cs],S) :- put_code(S,C),t_escribe_codigos(Cs,S).
t_terminos(F,Ts) :- open(F,read,S),t_lee_terminos(S,Ts),close(S).
t_lee_terminos(S,Ts) :- read(S,T),(T==end_of_file -> Ts=[];Ts=[T|Xs],t_lee_terminos(S,Xs)).

t_caso('salida: informe completo, aulas, hechos Prolog y CSV por la CLI',
    (t_cli(['instancias/pequena.dat','/tmp/horarios-pruebas-completo.txt',clpfd,
            '--heuristica=ff','--aulas','--prolog=/tmp/horarios-pruebas-completo.pl',
            '--csv=/tmp/horarios-pruebas-completo.csv'],0),
     t_contiene('/tmp/horarios-pruebas-completo.txt','SOLUCION ENCONTRADA'),
     t_contiene('/tmp/horarios-pruebas-completo.txt','DETALLE DE ASIGNACIONES'),
     t_contiene('/tmp/horarios-pruebas-completo.txt','HORARIO POR GRUPO:'),
     t_contiene('/tmp/horarios-pruebas-completo.txt','HORARIO POR PROFESOR:'),
     t_contiene('/tmp/horarios-pruebas-completo.txt','HORARIO POR AULA:'),
     t_contiene('/tmp/horarios-pruebas-completo.txt','RESUMEN'),
     t_contiene('/tmp/horarios-pruebas-completo.txt','METRICAS DE EJECUCION'),
     t_terminos('/tmp/horarios-pruebas-completo.pl',Ts),length(Ts,3),
     t_miembro(asignacion('LAB','G1',['P-1','P-2'],'LAB-1',_,_,2),Ts),
     t_comando([gprolog,'--consult-file','/tmp/horarios-pruebas-completo.pl',
               '--entry-goal','(findall(X,asignacion(X,_,_,_,_,_,_),Xs),length(Xs,3)->halt(0);halt(1))'],0))).
t_caso('salida: CSV escapa comas y comillas y conserva UTF-8',
    (t_cli(['instancias/salida-caracteres.dat','/tmp/horarios-pruebas-caracteres.txt',bt,
            '--csv=/tmp/horarios-pruebas-caracteres.csv',
            '--prolog=/tmp/horarios-pruebas-caracteres.pl'],0),
     t_contiene('/tmp/horarios-pruebas-caracteres.csv','"C,ñ""1"'),
     t_contiene('/tmp/horarios-pruebas-caracteres.csv','"P,ñ""1"'),
     t_terminos('/tmp/horarios-pruebas-caracteres.pl',Ts),
     Ts=[asignacion('C,ñ"1','G"1','P,ñ"1','A"1','L',1,1)],
     t_comando([gprolog,'--consult-file','/tmp/horarios-pruebas-caracteres.pl',
               '--entry-goal','(asignacion(_,_,_,_,_,1,1)->halt(0);halt(1))'],0))).
t_caso('CLI: argumentos con espacios y apostrofos llegan intactos',
    (t_copia('instancias/salida-caracteres.dat','/tmp/horarios prueba d\'entrada.dat'),
     t_cli(['/tmp/horarios prueba d\'entrada.dat','/tmp/horarios prueba d\'salida.txt',bt],0),
     t_contiene('/tmp/horarios prueba d\'salida.txt','SOLUCION ENCONTRADA'))).
t_caso('CLI: instancia invalida produce informe y codigo dos',
    (t_cli(['instancias/invalida.dat','/tmp/horarios-pruebas-invalida.txt',bt],2),
     t_contiene('/tmp/horarios-pruebas-invalida.txt','INSTANCIA INVALIDA'),
     t_contiene('/tmp/horarios-pruebas-invalida.txt','DIAGNOSTICO'))).
t_caso('CLI: archivo inexistente produce diagnostico y codigo dos',
    (t_cli(['instancias/archivo-no-existe.dat','/tmp/horarios-pruebas-ausente.txt',bt],2),
     t_contiene('/tmp/horarios-pruebas-ausente.txt','INSTANCIA INVALIDA'))).
t_caso('CLI: imposible global tiene diagnostico y codigo cero',
    (t_cli(['instancias/sin-solucion.dat','/tmp/horarios-pruebas-imposible.txt',clpfd],0),
     t_contiene('/tmp/horarios-pruebas-imposible.txt','SIN SOLUCION'),
     t_contiene('/tmp/horarios-pruebas-imposible.txt','Mayor demanda'),
     t_contiene('/tmp/horarios-pruebas-imposible.txt','excluyentes'))).
t_caso('CLI: limite produce informe completo sin asignaciones parciales',
    (t_cli(['instancias/pequena.dat','/tmp/horarios-pruebas-limite.txt',bt,
            '--limite=1','--prolog=/tmp/horarios-pruebas-limite.pl'],3),
     t_contiene('/tmp/horarios-pruebas-limite.txt','LIMITE ALCANZADO'),
     t_contiene('/tmp/horarios-pruebas-limite.txt','METRICAS DE EJECUCION'),
     t_terminos('/tmp/horarios-pruebas-limite.pl',[]))).
t_caso('CLI: error de escritura se informa con codigo cuatro',
    t_cli(['instancias/pequena.dat','/tmp',bt],4)).
t_caso('CLI: argumentos invalidos se rechazan con codigo 64',
    t_cli(['instancias/pequena.dat','/tmp/horarios-pruebas-error.txt',bt,'--heuristica=desconocida'],64)).
t_caso('CLI: no permite sobrescribir la instancia de entrada',
    (t_copia('instancias/pequena.dat','/tmp/horarios-pruebas-protegida.dat'),
     t_lee_archivo('/tmp/horarios-pruebas-protegida.dat',Antes),
     t_cli(['/tmp/horarios-pruebas-protegida.dat','/tmp/horarios-pruebas-protegida.dat',bt],64),
     t_lee_archivo('/tmp/horarios-pruebas-protegida.dat',Antes))).

t_estado_busqueda(estado(Os,Rs,Cs,Ms,Fs)) :-
    findall(K-V,opcion(K,V),Os),findall(R-L,restriccion(R,L),Rs),
    findall(K-N,bus_contador(K,N),Cs),findall(H-C,bus_mejor(H,C),Ms),
    findall(F,bus_corte(F),Fs).
t_caso('diagnostico: demuestra primer prefijo incompatible y conserva el estado',
    (t_carga('instancias/sin-solucion.dat'),ejecutar_busqueda(bt,[],sin_solucion,_),
     t_estado_busqueda(Antes),
     restriccion(excluyentes('C2','G','C3','G'),Linea),
     diagnosticar_restricciones(diagnostico(
       primera_inviable(Linea,excluyentes('C2','G','C3','G')),Impactos)),
     length(Impactos,3),t_estado_busqueda(Antes))).
t_caso('diagnostico: identifica imposibilidad de las reglas implicitas',
    (t_carga('instancias/pequena.dat'),
     retract(profesor('P-1',N,_,D)),assertz(profesor('P-1',N,3,D)),
     diagnosticar_restricciones(diagnostico(base_inviable,_)))).
t_caso('diagnostico: no confunde agotamiento de limite con imposibilidad',
    (t_carga('instancias/sin-solucion.dat'),t_opcion(limite,0),
     diagnosticar_restricciones(diagnostico(indeterminado(base,0),_)),
     opcion(limite,0))).
