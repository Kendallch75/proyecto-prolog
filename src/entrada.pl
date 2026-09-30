/* Lectura y validacion de instancias .dat. Compatible con GNU Prolog.
   GNU Prolog conserva texto UTF-8 como secuencias de bytes en sus atomos;
   el lector binario preserva esos bytes y comprueba su codificacion.
   La disponibilidad se refiere al COMIENZO de la sesion (PDF, 4.3).
*/

:- dynamic(config/2).
:- dynamic(aula/3).
:- dynamic(profesor/4).
:- dynamic(grupo/7).
:- dynamic(imparte/3).
:- dynamic(restriccion/2).
:- dynamic(error_instancia/2).
:- dynamic(ent_error_lectura/2).
:- dynamic(ent_seccion/2).
:- dynamic(ent_visto/2).
:- dynamic(ent_fuente/2).

cargar_instancia(Archivo) :-
    ent_reiniciar,
    catch(open(Archivo, read, Flujo, [type(binary)]), _,
          (ent_error(0, ['No se pudo abrir el archivo de instancia: ', Archivo]),
           Flujo = error)),
    ( Flujo == error -> true
    ; catch(ent_leer(Flujo, 1, ninguna), _,
            ent_error(0, ['No se pudo completar la lectura del archivo.'])),
      catch(close(Flujo), _, true)
    ),
    valida(Errores),
    Errores == [],
    ent_materializar_disponibilidades.

ent_reiniciar :-
    retractall(config(_, _)), retractall(aula(_, _, _)),
    retractall(profesor(_, _, _, _)), retractall(grupo(_, _, _, _, _, _, _)),
    retractall(imparte(_, _, _)), retractall(restriccion(_, _)),
    retractall(error_instancia(_, _)), retractall(ent_error_lectura(_, _)),
    retractall(ent_seccion(_, _)), retractall(ent_visto(_, _)),
    retractall(ent_fuente(_, _)).

ent_leer(Flujo, Linea, Seccion) :-
    ent_linea(Flujo, Bytes, Fin),
    ent_quitar_bom(Linea, Bytes, SinBom),
    ( ent_utf8(SinBom) ->
        ent_recortar(SinBom, Texto),
        ent_procesar(Texto, Linea, Seccion, Nueva)
    ; ent_error(Linea, ['Secuencia UTF-8 invalida.']), Nueva = Seccion
    ),
    ( Fin == si -> true
    ; Siguiente is Linea + 1, ent_leer(Flujo, Siguiente, Nueva)
    ).

ent_linea(Flujo, Bytes, Fin) :-
    get_byte(Flujo, B), ent_linea_byte(B, Flujo, Bytes, Fin).
ent_linea_byte(-1, _, [], si) :- !.
ent_linea_byte(10, _, [], no) :- !.
ent_linea_byte(B, Flujo, [B|Resto], Fin) :- ent_linea(Flujo, Resto, Fin).

ent_quitar_bom(1, [239,187,191|Resto], Resto) :- !.
ent_quitar_bom(_, Bytes, Bytes).

ent_procesar([], _, Seccion, Seccion) :- !.
ent_procesar([35,58|Nombre0], Linea, _, Seccion) :- !,
    ent_recortar(Nombre0, Nombre), atom_codes(Atomo, Nombre),
    ( ent_nombre_seccion(Atomo) ->
        Seccion = Atomo,
        ( ent_seccion(Atomo, Anterior) ->
            ent_error(Linea, ['Seccion duplicada ', Atomo,
                             ' (primera declaracion en linea ', Anterior, ').'])
        ; assertz(ent_seccion(Atomo, Linea))
        )
    ; Seccion = desconocida,
      ent_error(Linea, ['Seccion desconocida: ', Atomo, '.'])
    ).
ent_procesar([35|_], _, Seccion, Seccion) :- !.
ent_procesar(_, Linea, ninguna, ninguna) :- !,
    ent_error(Linea, ['Registro antes de cualquier seccion.']).
ent_procesar(_, Linea, desconocida, desconocida) :- !,
    ent_error(Linea, ['Registro dentro de una seccion desconocida.']).
ent_procesar(Texto, Linea, Seccion, Seccion) :-
    ( ent_miembro(35, Texto) ->
        ent_error(Linea, ['El caracter # no se permite dentro de un registro.'])
    ; ent_separar(59, Texto, Campos0), ent_recortar_lista(Campos0, Campos),
      ent_registro(Seccion, Campos, Linea)
    ).

ent_nombre_seccion('CONFIG').
ent_nombre_seccion('AULA').
ent_nombre_seccion('PROFESOR').
ent_nombre_seccion('CURSO').
ent_nombre_seccion('IMPARTE').
ent_nombre_seccion('RESTRICCION').

ent_registro('CONFIG', [ClaveCs, Valor], Linea) :- !,
    atom_codes(Clave, ClaveCs),
    ent_unico(config(Clave), Linea),
    ent_config(Clave, Valor, Linea, Dato),
    ent_guardar(config(Clave, Dato), config(Clave), Linea).
ent_registro('AULA', [CodigoCs, CapCs, TipoCs], Linea) :- !,
    ent_texto(CodigoCs, codigo_aula, Linea, Codigo),
    ent_natural(CapCs, capacidad, Linea, Capacidad),
    ent_tipo(TipoCs, Linea, Tipo),
    ent_unico(aula(Codigo), Linea),
    ent_guardar(aula(Codigo, Capacidad, Tipo), aula(Codigo), Linea).
ent_registro('PROFESOR', [CodigoCs, NombreCs, MaxCs, DispCs], Linea) :- !,
    ent_texto(CodigoCs, codigo_profesor, Linea, Codigo),
    ent_texto(NombreCs, nombre, Linea, Nombre),
    ent_natural(MaxCs, max_franjas, Linea, Max),
    ent_disponibilidad(DispCs, Linea, Disponibilidad),
    ent_unico(profesor(Codigo), Linea),
    ent_guardar(profesor(Codigo, Nombre, Max, Disponibilidad), profesor(Codigo), Linea).
ent_registro('CURSO', [CodigoCs, NombreCs, GrupoCs, InsCs, SemCs, DurCs, TipoCs], Linea) :- !,
    ent_texto(CodigoCs, codigo_curso, Linea, Codigo),
    ent_texto(NombreCs, nombre, Linea, Nombre),
    ent_texto(GrupoCs, grupo, Linea, Grupo),
    ent_natural(InsCs, inscritos, Linea, Inscritos),
    ent_positivo(SemCs, semanales, Linea, Semanales),
    ent_positivo(DurCs, duracion, Linea, Duracion),
    ent_tipo(TipoCs, Linea, Tipo),
    ent_unico(grupo(Codigo, Grupo), Linea),
    ent_guardar(grupo(Codigo, Grupo, Nombre, Inscritos, Semanales, Duracion, Tipo),
                grupo(Codigo, Grupo), Linea).
ent_registro('IMPARTE', [CursoCs, GrupoCs, ProfCs], Linea) :- !,
    ent_texto(CursoCs, curso, Linea, Curso),
    ent_texto(GrupoCs, grupo, Linea, Grupo),
    ent_texto(ProfCs, profesor, Linea, Prof),
    ent_unico(imparte(Curso, Grupo, Prof), Linea),
    ent_guardar(imparte(Curso, Grupo, Prof), imparte(Curso, Grupo, Prof), Linea).
ent_registro('RESTRICCION', [TipoCs|Argumentos], Linea) :- !,
    atom_codes(Tipo, TipoCs), ent_restriccion(Tipo, Argumentos, Linea).
ent_registro(Seccion, _, Linea) :-
    ent_error(Linea, ['Cantidad incorrecta de campos en ', Seccion, '.']).

ent_config(dias, Cs, Linea, Dias) :- !,
    ent_separar(44, Cs, Dias0), ent_recortar_lista(Dias0, DiasCs),
    ent_dias(DiasCs, Linea, Dias),
    ( ent_sin_duplicados(Dias) -> true
    ; ent_error(Linea, ['Hay codigos de dia repetidos en dias.'])
    ).
ent_config(franjas, Cs, Linea, N) :- !, ent_positivo(Cs, franjas, Linea, N).
ent_config(duracion_franja, Cs, Linea, N) :- !,
    ent_positivo(Cs, duracion_franja, Linea, N).
ent_config(inicio, Cs, Linea, Minutos) :- !,
    ( Cs = [H1,H2,58,M1,M2], ent_digitos([H1,H2,M1,M2]),
      H is (H1-48)*10+H2-48, M is (M1-48)*10+M2-48,
      H < 24, M < 60 -> Minutos is H*60+M
    ; Minutos = 0,
      ent_error(Linea, ['inicio debe tener formato HH:MM, entre 00:00 y 23:59.'])
    ).
ent_config(Clave, _, Linea, invalido) :-
    ent_error(Linea, ['Clave CONFIG desconocida: ', Clave, '.']).

ent_dias([], _, []).
ent_dias([Cs|Resto], Linea, [Dia|Dias]) :-
    atom_codes(Dia, Cs),
    ( ent_caracter_utf8(Cs, []) -> true
    ; ent_error(Linea, ['Cada codigo de dia debe contener exactamente un caracter: ', Dia, '.'])
    ),
    ent_dias(Resto, Linea, Dias).

ent_restriccion(aula_fija, [CC, GC, AC], L) :- !,
    ent_texto(CC, curso, L, C), ent_texto(GC, grupo, L, G),
    ent_texto(AC, aula, L, A),
    ent_guardar(restriccion(aula_fija(C,G,A), L), restriccion(aula_fija(C,G,A)), L).
ent_restriccion(prohibida, [CC, GC, SC], L) :- !,
    ent_texto(CC, curso, L, C), ent_texto(GC, grupo, L, G),
    ent_slot(SC, L, D, F),
    ent_guardar(restriccion(prohibida(C,G,D,F), L), restriccion(prohibida(C,G,D,F)), L).
ent_restriccion(excluyentes, [CC1, GC1, CC2, GC2], L) :- !,
    ent_texto(CC1, curso, L, C1), ent_texto(GC1, grupo, L, G1),
    ent_texto(CC2, curso, L, C2), ent_texto(GC2, grupo, L, G2),
    ent_guardar(restriccion(excluyentes(C1,G1,C2,G2), L),
                restriccion(excluyentes(C1,G1,C2,G2)), L).
ent_restriccion(prefiere, [CC, GC, SC, WC], L) :- !,
    ent_texto(CC, curso, L, C), ent_texto(GC, grupo, L, G),
    ent_slot(SC, L, D, F), ent_natural(WC, peso, L, W),
    ent_guardar(restriccion(prefiere(C,G,D,F,W), L), restriccion(prefiere(C,G,D,F,W)), L).
ent_restriccion(compacta, [CC, GC, WC], L) :- !,
    ent_texto(CC, curso, L, C), ent_texto(GC, grupo, L, G),
    ent_natural(WC, peso, L, W),
    ent_guardar(restriccion(compacta(C,G,W), L), restriccion(compacta(C,G,W)), L).
ent_restriccion(Tipo, _, L) :-
    ( ent_miembro(Tipo, [aula_fija,prohibida,excluyentes,prefiere,compacta]) ->
        ent_error(L, ['Cantidad incorrecta de argumentos para ', Tipo, '.'])
    ; ent_error(L, ['Tipo de restriccion desconocido: ', Tipo, '.'])
    ).

ent_texto(Cs, Campo, Linea, Atomo) :-
    atom_codes(Atomo, Cs),
    ( Cs == [] -> ent_error(Linea, ['El campo ', Campo, ' no puede estar vacio.']) ; true ).

ent_natural(Cs, Campo, Linea, N) :-
    ( Cs = [_|_], ent_digitos(Cs), catch(number_codes(N, Cs), _, fail), integer(N), N >= 0 -> true
    ; N = 0, ent_error(Linea, ['El campo ', Campo, ' debe ser un entero decimal no negativo.'])
    ).
ent_positivo(Cs, Campo, Linea, N) :-
    ent_natural(Cs, Campo, Linea, N),
    ( N > 0 -> true
    ; ent_error(Linea, ['El campo ', Campo, ' debe ser mayor que cero.'])
    ).
ent_digitos([]).
ent_digitos([C|Cs]) :- C >= 48, C =< 57, ent_digitos(Cs).

ent_tipo(Cs, Linea, Tipo) :-
    atom_codes(Tipo, Cs),
    ( ent_miembro(Tipo, [teoria,laboratorio,mixta]) -> true
    ; ent_error(Linea, ['Tipo de aula o requerimiento desconocido: ', Tipo, '.'])
    ).

ent_slot(Cs0, Linea, D, F) :-
    ent_recortar(Cs0, Cs),
    ( ent_caracter_utf8(Cs, Numeros), Numeros = [_|_], ent_digitos(Numeros),
      catch(number_codes(F, Numeros), _, fail), integer(F), F >= 0 ->
        ent_concatenar(DiaCs, Numeros, Cs), atom_codes(D, DiaCs)
    ; D = invalido, F = 0,
      ent_error(Linea, ['Franja invalida; se esperaba un dia seguido de un entero, por ejemplo L1.'])
    ).

ent_disponibilidad([], _, todos) :- !.
ent_disponibilidad(Cs, Linea, rangos(Valores)) :-
    ent_separar(44, Cs, Rangos), ent_rangos(Rangos, Linea, Valores).
ent_rangos([], _, []).
ent_rangos([Rango|Rangos], Linea, Slots) :-
    ent_separar(45, Rango, Partes),
    ( Partes = [Inicio, Fin] ->
        ent_slot(Inicio, Linea, D1, F1), ent_slot(Fin, Linea, D2, F2),
        ( D1 == D2, F1 =< F2 -> Estos = [rango(D1,F1,F2)]
        ; Estos = [], ent_error(Linea, ['Disponibilidad: el rango debe ser creciente y de un mismo dia.'])
        )
    ; Estos = [], ent_error(Linea, ['Disponibilidad: se esperaba un rango Df-Df.'])
    ),
    ent_rangos(Rangos, Linea, Otros), ent_concatenar(Estos, Otros, Slots).
/* Se expanden los rangos solo despues de comprobar sus extremos. Un rango
   erroneo enorme no debe agotar memoria antes de informar su numero de linea. */
ent_materializar_disponibilidades :-
    findall(datos(P,N,M,R), profesor(P,N,M,rangos(R)), Profesores),
    ent_materializar_profesores(Profesores).
ent_materializar_profesores([]).
ent_materializar_profesores([datos(P,N,M,R)|Ps]) :-
    ent_expandir_rangos(R,Slots0), sort(Slots0,Slots),
    retractall(profesor(P,_,_,_)), assertz(profesor(P,N,M,Slots)),
    ent_materializar_profesores(Ps).
ent_expandir_rangos([], []).
ent_expandir_rangos([rango(D,Desde,Hasta)|Rs], Slots) :-
    ent_expandir(D,Desde,Hasta,Estos), ent_expandir_rangos(Rs,Otros),
    ent_concatenar(Estos,Otros,Slots).
ent_disponibilidad_extremo(rangos(Rs),D,F) :-
    ent_miembro(rango(D,Desde,Hasta),Rs), (F = Desde ; F = Hasta).
ent_disponibilidad_extremo(Slots,D,F) :-
    Slots \== todos, Slots \= rangos(_), ent_miembro(slot(D,F),Slots).

ent_expandir(_, Inicio, Fin, []) :- Inicio > Fin, !.
ent_expandir(Dia, Inicio, Fin, [slot(Dia,Inicio)|Resto]) :-
    Siguiente is Inicio+1, ent_expandir(Dia, Siguiente, Fin, Resto).

ent_unico(Clave, Linea) :-
    ( ent_visto(Clave, Anterior) ->
        ent_etiqueta_clave(Clave, Etiqueta),
        ent_error(Linea, ['Declaracion duplicada de ', Etiqueta,
                         ' (primera declaracion en linea ', Anterior, ').'])
    ; assertz(ent_visto(Clave, Linea))
    ).
ent_etiqueta_clave(config(K), K).
ent_etiqueta_clave(aula(A), A).
ent_etiqueta_clave(profesor(P), P).
ent_etiqueta_clave(grupo(C,G), Etiqueta) :- ent_mensaje([C,'/',G], Etiqueta).
ent_etiqueta_clave(imparte(C,G,P), Etiqueta) :- ent_mensaje([C,'/',G,'/',P], Etiqueta).
ent_guardar(Hecho, Clave, Linea) :-
    ( ent_error_lectura(Linea, _) -> true
    ; assertz(Hecho), assertz(ent_fuente(Clave, Linea))
    ).

/* valida/1 es repetible: regenera la lista completa sin duplicar mensajes. */
valida(Errores) :-
    retractall(error_instancia(_, _)),
    ( ent_error_lectura(L, M), assertz(error_instancia(L,M)), fail ; true ),
    ( ent_error_coherencia(Linea, Partes),
      ent_mensaje(Partes, Mensaje),
      ( error_instancia(Linea, Mensaje) -> true ; assertz(error_instancia(Linea, Mensaje)) ),
      fail
    ; true
    ),
    findall(error(N, Texto), error_instancia(N, Texto), SinOrden),
    sort(SinOrden, Errores).

ent_error_coherencia(1, ['Falta la seccion obligatoria CONFIG.']) :-
    \+ ent_seccion('CONFIG', _).
ent_error_coherencia(L, ['Falta una clave CONFIG valida: ', Clave, '.']) :-
    ent_miembro(Clave, [dias,franjas,inicio,duracion_franja]),
    \+ config(Clave, _), ent_linea_config(L).
ent_error_coherencia(L, ['La duracion del grupo ', C,'/',G,
                        ' excede el numero de franjas del dia.']) :-
    grupo(C,G,_,_,_,Dur,_), config(franjas,F), Dur > F,
    ent_linea_fuente(grupo(C,G),L).
ent_error_coherencia(L, ['El grupo ', C,'/',G,' no tiene profesor declarado.']) :-
    grupo(C,G,_,_,_,_,_), \+ imparte(C,G,_), ent_linea_fuente(grupo(C,G),L).
ent_error_coherencia(L, ['Referencia a grupo inexistente: ', C,'/',G,'.']) :-
    imparte(C,G,P), \+ grupo(C,G,_,_,_,_,_), ent_linea_fuente(imparte(C,G,P),L).
ent_error_coherencia(L, ['Referencia a profesor inexistente: ', P,'.']) :-
    imparte(C,G,P), \+ profesor(P,_,_,_), ent_linea_fuente(imparte(C,G,P),L).
ent_error_coherencia(L, Mensaje) :-
    profesor(P,_,_,Slots), ent_disponibilidad_extremo(Slots,D,F),
    ent_linea_fuente(profesor(P),L), ent_error_slot(D,F,Mensaje).
ent_error_coherencia(L, ['Referencia a grupo inexistente: ', C,'/',G,'.']) :-
    restriccion(T,L), ent_grupo_restriccion(T,C,G), \+ grupo(C,G,_,_,_,_,_).
ent_error_coherencia(L, ['Referencia a aula inexistente: ', A,'.']) :-
    restriccion(aula_fija(_,_,A),L), \+ aula(A,_,_).
ent_error_coherencia(L, Mensaje) :-
    restriccion(T,L), ent_slot_restriccion(T,D,F), ent_error_slot(D,F,Mensaje).

ent_grupo_restriccion(aula_fija(C,G,_),C,G).
ent_grupo_restriccion(prohibida(C,G,_,_),C,G).
ent_grupo_restriccion(excluyentes(C,G,_,_),C,G).
ent_grupo_restriccion(excluyentes(_,_,C,G),C,G).
ent_grupo_restriccion(prefiere(C,G,_,_,_),C,G).
ent_grupo_restriccion(compacta(C,G,_),C,G).
ent_slot_restriccion(prohibida(_,_,D,F),D,F).
ent_slot_restriccion(prefiere(_,_,D,F,_),D,F).
ent_error_slot(D, _, ['Codigo de dia no declarado en dias: ',D,'.']) :-
    config(dias,Dias), \+ ent_miembro(D,Dias).
ent_error_slot(D, F, ['Franja fuera del rango configurado: ',D,F,'.']) :-
    config(franjas,Max), (F < 1 ; F > Max).

ent_linea_config(L) :- ent_seccion('CONFIG',L), !.
ent_linea_config(1).
ent_linea_fuente(Clave,L) :- ent_fuente(Clave,L), !.
ent_linea_fuente(_,0).

ent_error(Linea, Partes) :-
    ent_mensaje(Partes, Mensaje),
    ( ent_error_lectura(Linea, Mensaje) -> true
    ; assertz(ent_error_lectura(Linea, Mensaje))
    ).
ent_mensaje(Partes, Mensaje) :- ent_codigos_partes(Partes, Cs), atom_codes(Mensaje,Cs).
ent_codigos_partes([], []).
ent_codigos_partes([Parte|Partes], Cs) :-
    ( number(Parte) -> number_codes(Parte, Estos) ; atom_codes(Parte, Estos) ),
    ent_codigos_partes(Partes, Otros), ent_concatenar(Estos, Otros, Cs).

ent_recortar(Cs, Resultado) :-
    ent_sin_blanco_inicial(Cs, Inicio), reverse(Inicio, Rev),
    ent_sin_blanco_inicial(Rev, RevLimpio), reverse(RevLimpio, Resultado).
ent_sin_blanco_inicial([C|Cs], Resultado) :- ent_blanco(C), !,
    ent_sin_blanco_inicial(Cs, Resultado).
ent_sin_blanco_inicial(Cs, Cs).
ent_blanco(32).
ent_blanco(9).
ent_blanco(13).
ent_recortar_lista([], []).
ent_recortar_lista([Cs|Resto], [Limpio|Limpios]) :-
    ent_recortar(Cs,Limpio), ent_recortar_lista(Resto,Limpios).

ent_separar(Separador, Cs, [Primero|Resto]) :-
    ent_hasta(Separador,Cs,Primero,Cola,Encontrado),
    ( Encontrado == si -> ent_separar(Separador,Cola,Resto) ; Resto = [] ).
ent_hasta(_, [], [], [], no).
ent_hasta(S, [S|Cs], [], Cs, si) :- !.
ent_hasta(S, [C|Cs], [C|Parte], Resto, Hay) :- ent_hasta(S,Cs,Parte,Resto,Hay).
ent_concatenar([], X, X).
ent_concatenar([X|Xs], Ys, [X|Zs]) :- ent_concatenar(Xs,Ys,Zs).
ent_miembro(X, [X|_]).
ent_miembro(X, [_|Xs]) :- ent_miembro(X,Xs).
ent_sin_duplicados([]).
ent_sin_duplicados([X|Xs]) :- \+ ent_miembro(X,Xs), ent_sin_duplicados(Xs).

/* Reconoce escalares Unicode validos, excluyendo codificaciones sobrelargas,
   sustitutos y puntos superiores a U+10FFFF. */
ent_utf8([]).
ent_utf8(Cs) :- ent_caracter_utf8(Cs,Resto), ent_utf8(Resto).
ent_caracter_utf8([C|Cs], Cs) :- C >= 0, C =< 127, !.
ent_caracter_utf8([C,B|Cs], Cs) :- C >= 194, C =< 223, ent_continuacion(B), !.
ent_caracter_utf8([224,B,C|Cs], Cs) :- B >= 160, B =< 191, ent_continuacion(C), !.
ent_caracter_utf8([A,B,C|Cs], Cs) :- A >= 225, A =< 236,
    ent_continuacion(B), ent_continuacion(C), !.
ent_caracter_utf8([237,B,C|Cs], Cs) :- B >= 128, B =< 159, ent_continuacion(C), !.
ent_caracter_utf8([A,B,C|Cs], Cs) :- A >= 238, A =< 239,
    ent_continuacion(B), ent_continuacion(C), !.
ent_caracter_utf8([240,B,C,D|Cs], Cs) :- B >= 144, B =< 191,
    ent_continuacion(C), ent_continuacion(D), !.
ent_caracter_utf8([A,B,C,D|Cs], Cs) :- A >= 241, A =< 243,
    ent_continuacion(B), ent_continuacion(C), ent_continuacion(D), !.
ent_caracter_utf8([244,B,C,D|Cs], Cs) :- B >= 128, B =< 143,
    ent_continuacion(C), ent_continuacion(D).
ent_continuacion(C) :- C >= 128, C =< 191.
