% Modelo declarativo y comprobacion independiente del horario.
% Una asignacion: asig(Curso,Grupo,NumeroSesion,Aula,Dia,Inicio,Duracion).

sesiones(Lista) :-
    findall(sesion(C,G,I), (grupo(C,G,_,_,N,_,_), mod_entre(1,N,I)), Lista).

mod_entre(A,B,A) :- A =< B.
mod_entre(A,B,X) :- A < B, A1 is A+1, mod_entre(A1,B,X).
mod_miembro(X,[X|_]).
mod_miembro(X,[_|Xs]) :- mod_miembro(X,Xs).
mod_suma([],0).
mod_suma([X|Xs],S) :- mod_suma(Xs,R), S is X+R.
mod_longitud([],0).
mod_longitud([_|Xs],N) :- mod_longitud(Xs,M), N is M+1.

dominio(sesion(C,G,I),Valores) :-
    grupo(C,G,_,Ins,N,Dur,Tipo), mod_entre(1,N,I),
    config(dias,Dias), config(franjas,Fmax), Ult is Fmax-Dur+1,
    findall(asig(C,G,I,A,D,F,Dur),
      (aula(A,Cap,TA), Cap>=Ins, tipo_compatible(Tipo,TA),
       mod_miembro(D,Dias), mod_entre(1,Ult,F),
       mod_profesores_disponibles(C,G,D,F),
       \+ (restriccion(aula_fija(C,G,AF),_), A\==AF),
       Fin is F+Dur-1,
       \+ (restriccion(prohibida(C,G,D,FP),_), FP>=F, FP=<Fin)), Valores).

tipo_compatible(teoria,teoria).
tipo_compatible(teoria,mixta).
tipo_compatible(laboratorio,laboratorio).
tipo_compatible(laboratorio,mixta).
% 'mixta' no impone un tipo exclusivo; acepta cualquiera de los tres.
tipo_compatible(mixta,teoria).
tipo_compatible(mixta,laboratorio).
tipo_compatible(mixta,mixta).

mod_profesores_disponibles(C,G,D,F) :-
    \+ (imparte(C,G,P), profesor(P,_,_,Disp), \+ mod_disponible(Disp,D,F)).
mod_disponible(todos,_,_).
mod_disponible(Disp,D,F) :- Disp\==todos, mod_miembro(slot(D,F),Disp).

comparten_profesor(C,G,C2,G2) :- imparte(C,G,P), imparte(C2,G2,P), !.
grupos_excluyentes(C,G,C2,G2) :- restriccion(excluyentes(C,G,C2,G2),_), !.
grupos_excluyentes(C,G,C2,G2) :- restriccion(excluyentes(C2,G2,C,G),_), !.

compatible_asignaciones(asig(C,G,_,A,D,F,L),asig(C2,G2,_,A2,D2,F2,L2)) :-
    (D\==D2 -> true
    ; F+L=<F2 -> true
    ; F2+L2=<F -> true
    ; A\==A2, \+ (C==C2,G==G2),
      \+ comparten_profesor(C,G,C2,G2), \+ grupos_excluyentes(C,G,C2,G2)).

% NO llama dominio/2 ni compatible_asignaciones/2: validacion independiente.
verifica(H) :-
    ground(H), mod_es_lista(H), sesiones(S),
    findall(sesion(C,G,I),mod_miembro(asig(C,G,I,_,_,_,_),H),SH),
    mod_longitud(H,N), mod_longitud(S,N), mod_longitud(SH,N),
    sort(S,SS), sort(SH,SS),
    \+ (mod_miembro(X,H), \+ ver_unaria(X)),
    ver_pares(H),
    \+ (profesor(P,_,Max,_), demanda_profesor(P,T), T>Max).
mod_es_lista([]).
mod_es_lista([_|Xs]) :- mod_es_lista(Xs).
ver_unaria(asig(C,G,I,A,D,F,L)) :-
    grupo(C,G,_,Ins,N,L,T), integer(I), I>=1, I=<N,
    aula(A,Cap,TA), Cap>=Ins, ver_tipo(T,TA),
    config(dias,Ds), mod_miembro(D,Ds), config(franjas,Max),
    integer(F), F>=1, Fin is F+L-1, Fin=<Max,
    \+ (imparte(C,G,P), profesor(P,_,_,Disp),
        Disp\==todos, \+ mod_miembro(slot(D,F),Disp)),
    \+ (restriccion(aula_fija(C,G,AF),_), AF\==A),
    \+ (restriccion(prohibida(C,G,D,FP),_), FP>=F, FP=<Fin).
ver_tipo(teoria,T) :- (T==teoria; T==mixta).
ver_tipo(laboratorio,T) :- (T==laboratorio; T==mixta).
ver_tipo(mixta,T) :- (T==teoria; T==laboratorio; T==mixta).
ver_pares([]).
ver_pares([X|Xs]) :- \+ (mod_miembro(Y,Xs),ver_conflicto(X,Y)), ver_pares(Xs).
ver_conflicto(asig(C,G,_,A,D,F,L),asig(C2,G2,_,A2,D,F2,L2)) :-
    F<F2+L2, F2<F+L,
    (A==A2; C==C2,G==G2; imparte(C,G,P),imparte(C2,G2,P);
     restriccion(excluyentes(C,G,C2,G2),_);
     restriccion(excluyentes(C2,G2,C,G),_)).

demanda_profesor(P,N) :-
    findall(K,(imparte(C,G,P),grupo(C,G,_,_,S,D,_),K is S*D),Ks),mod_suma(Ks,N).

huecos_grupo(H,C,G,N) :- mod_huecos(H,grupo(C,G),N).
huecos_profesor(H,P,N) :- mod_huecos(H,profesor(P),N).
mod_huecos(H,Entidad,N) :- config(dias,Ds),
    findall(K,(mod_miembro(D,Ds),mod_huecos_dia(H,Entidad,D,K)),Ks),mod_suma(Ks,N).
mod_ocupa(H,grupo(C,G),D,F) :- mod_miembro(asig(C,G,_,_,D,Ini,Dur),H),Fin is Ini+Dur-1,mod_entre(Ini,Fin,F).
mod_ocupa(H,profesor(P),D,F) :- mod_miembro(asig(C,G,_,_,D,Ini,Dur),H),imparte(C,G,P),Fin is Ini+Dur-1,mod_entre(Ini,Fin,F).
mod_huecos_dia(H,E,D,N) :-
    findall(F,mod_ocupa(H,E,D,F),Fs), sort(Fs,Unicos),
    (Unicos=[] -> N=0 ; Unicos=[Prim|_], mod_ultimo(Unicos,Ult),mod_longitud(Unicos,K),N is Ult-Prim+1-K).
mod_ultimo([X],X).
mod_ultimo([_|Xs],X) :- mod_ultimo(Xs,X).

costo(H,Costo) :-
    findall(W,(restriccion(prefiere(C,G,D,F,W),_),\+ mod_miembro(asig(C,G,_,_,D,F,_),H)),Prefs),
    findall(V,(restriccion(compacta(C,G,W),_),huecos_grupo(H,C,G,N),V is W*N),Compactas),
    mod_suma(Prefs,P),mod_suma(Compactas,K),Costo is P+K.

% Prechequeos necesarios: solo razones demostrables de inconsistencia.
inconsistencias(Razones) :- findall(R,mod_inconsistencia(R),Razones).
mod_inconsistencia(grupo_sin_dominio(C,G)) :- grupo(C,G,_,_,_,_,_),dominio(sesion(C,G,1),[]).
mod_inconsistencia(demanda_grupo(C,G,Dem,Disp)) :-
    grupo(C,G,_,_,N,Dur,_),config(dias,Ds),mod_longitud(Ds,ND),config(franjas,F),
    Dem is N*Dur,Disp is ND*F,Dem>Disp.
mod_inconsistencia(limite_profesor(P,Dem,Max)) :- profesor(P,_,Max,_),demanda_profesor(P,Dem),Dem>Max.
mod_inconsistencia(inicios_profesor(P,N,Disp)) :-
    profesor(P,_,_,Slots), Slots\==todos,
    findall(S,(imparte(C,G,P),grupo(C,G,_,_,S,_,_)),Ss),mod_suma(Ss,N),
    sort(Slots,U),mod_longitud(U,Disp),N>Disp.
mod_inconsistencia(capacidad_global(Dem,Disp)) :-
    findall(N,(grupo(_,_,_,_,S,D,_),N is S*D),Ns),mod_suma(Ns,Dem),
    findall(A,aula(A,_,_),As),mod_longitud(As,NA),config(dias,Ds),mod_longitud(Ds,ND),
    config(franjas,F),Disp is NA*ND*F,Dem>Disp.

% El producto se calcula por factores en float: evita overflow en instancias grandes.
espacio_busqueda(Sesiones,Log10) :- sesiones(S),mod_longitud(S,Sesiones),
    findall(A,aula(A,_,_),As),mod_longitud(As,NA),config(dias,Ds),mod_longitud(Ds,ND),config(franjas,F),
    findall(V,(grupo(_,_,_,_,N,D,_),B is NA*ND*(F-D+1),
              (B>0 -> V is N*log(B)/log(10); V=0)),Vs),mod_suma(Vs,Log10).
