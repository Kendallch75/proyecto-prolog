/* Banco reproducible: cargar junto a horarios.pl.
   Todo el procesamiento, medicion, CSV y grafico se realiza en GNU Prolog. */
:- dynamic(exp_resultado/11).

experimentos(Modo, ArchivoCSV, ArchivoSVG) :-
    member(Modo, [interpretado,nativo]),
    retractall(exp_resultado(_,_,_,_,_,_,_,_,_,_,_)),
    open(ArchivoCSV, write, CSV),
    catch((
      write(CSV, 'modo,instancia,sesiones,configuracion,estado,costo,optimo,nodos,retrocesos,cpu_s,pared_s,aceleracion,eficiencia'), nl(CSV),
      exp_instancias(Instancias), exp_correr_instancias(Instancias, Modo, CSV)
    ), Error, (close(CSV), throw(Error))),
    close(CSV),
    exp_escribir_svg(ArchivoSVG, Modo),
    format('Experimentos finalizados: ~a y ~a~n', [ArchivoCSV,ArchivoSVG]).

exp_instancias([
  pequena-'instancias/pequena.dat',
  campus-'instancias/campus-central.dat',
  escala20-'instancias/escala-20.dat',
  escala40-'instancias/escala-40.dat',
  escala80-'instancias/escala-80.dat']).
exp_configuraciones([bt_ingenuo,bt_mrv,bt_grado,bt_demanda,bt_lcv,clpfd_ff,clpfd_opt]).

exp_configurar(Config, Estrategia) :-
    opciones_defecto,
    cli_opcion(limite, 5000),
    exp_opciones(Config, Estrategia).
exp_opciones(bt_ingenuo, bt) :-
    cli_opcion(simetria,no),cli_opcion(anticipada,no),cli_opcion(heuristica,original).
exp_opciones(bt_mrv, bt) :- cli_opcion(anticipada,si),cli_opcion(heuristica,mrv).
exp_opciones(bt_grado, bt) :- cli_opcion(anticipada,si),cli_opcion(heuristica,grado).
exp_opciones(bt_demanda, bt) :- cli_opcion(anticipada,si),cli_opcion(heuristica,demanda).
exp_opciones(bt_lcv, bt) :-
    cli_opcion(anticipada,si),cli_opcion(heuristica,mrv),cli_opcion(valor,lcv).
exp_opciones(clpfd_ff, clpfd) :- cli_opcion(heuristica,ff).
exp_opciones(clpfd_opt, clpfd) :- cli_opcion(heuristica,ff),cli_opcion(optimizar,si).

exp_correr_instancias([], _, _).
exp_correr_instancias([Nombre-Archivo|Is], Modo, CSV) :-
    exp_configuraciones(Configs),
    exp_correr_configs(Configs, Nombre, Archivo, Modo, CSV),
    exp_correr_instancias(Is, Modo, CSV).
exp_correr_configs([], _, _, _, _).
exp_correr_configs([Config|Cs], Nombre, Archivo, Modo, CSV) :-
    exp_corrida(Modo,Nombre,Archivo,Config,CSV),
    exp_correr_configs(Cs,Nombre,Archivo,Modo,CSV).

exp_corrida(Modo, Nombre, Archivo, Config, CSV) :-
    exp_configurar(Config, Estrategia),
    format('Midiendo ~a / ~a / ~a ...~n', [Modo,Nombre,Config]),
    exp_repeticiones(Nombre,Repeticiones),
    statistics(runtime,[CPU0,_]),statistics(real_time,[Pared0,_]),
    catch((exp_repetir(Repeticiones,Archivo,Estrategia,NS,Estado,Coste,Optimo,Nodos,Retrocesos)
           -> true ; throw(error(experimento_fallo,Nombre-Config))),
          Error, (format(user_error,'Error experimental en ~a / ~a: ~q~n',[Nombre,Config,Error]),
                  NS=0,Estado=error,Coste=na,Optimo=no,Nodos=0,Retrocesos=0)),
    statistics(runtime,[CPU1,_]),statistics(real_time,[Pared1,_]),
    CPU is (CPU1-CPU0)/(1000*Repeticiones), Pared is (Pared1-Pared0)/(1000*Repeticiones),
    assertz(exp_resultado(Modo,Nombre,NS,Config,Estado,Coste,Optimo,Nodos,Retrocesos,CPU,Pared)),
    exp_ratios(Modo,Nombre,Config,Estado,Nodos,CPU,Aceleracion,Eficiencia),
    format(CSV,'~a,~a,~d,~a,~a,~w,~a,~d,~d,~6f,~6f,',[Modo,Nombre,NS,Config,Estado,Coste,Optimo,Nodos,Retrocesos,CPU,Pared]),
    exp_csv_ratio(CSV,Aceleracion),write(CSV,','),exp_csv_ratio(CSV,Eficiencia),nl(CSV),
    format('  ~a; ~d nodos; CPU ~3f s; pared ~3f s; costo ~w~n',[Estado,Nodos,CPU,Pared,Coste]).

% La instancia de tres sesiones suele tardar menos de un tick (1 ms).
% Se promedian cien ejecuciones completas; los contadores son POR ejecucion.
exp_repeticiones(pequena,100) :- !.
exp_repeticiones(_,1).
exp_repetir(0,_,_,_,_,_,_,_,_) :- !.
exp_repetir(N,Archivo,Estrategia,NS,Estado,Coste,Optimo,Nodos,Retrocesos) :-
    exp_evaluar(Archivo,Estrategia,NS,Estado,Coste,Optimo,Nodos,Retrocesos),
    Siguiente is N-1,
    exp_repetir(Siguiente,Archivo,Estrategia,NS,Estado,Coste,Optimo,Nodos,Retrocesos).

exp_evaluar(Archivo,Estrategia,NS,Estado,Coste,Optimo,Nodos,Retrocesos) :-
    ( cargar_instancia(Archivo) ->
        sesiones(Sesiones),length(Sesiones,NS),
        ejecutar_busqueda(Estrategia,H,Estado,Optimo),
        metricas_busqueda(Nodos,Retrocesos),
        ( (H\=[] ; Estado==solucion) ->
            (verifica(H) -> costo(H,Coste)
            ; throw(error(verificacion_independiente_fallo,Archivo)))
        ; Coste=na )
    ; Estado=invalida,NS=0,Coste=na,Optimo=no,Nodos=0,Retrocesos=0
    ).

% La clausula anterior distingue carga invalida, horario completo e inexistente.
% Un limite con incumbente conserva su costo; nunca se verifica una lista parcial.

exp_completa(solucion).
exp_completa(sin_solucion).
exp_ratios(Modo,Inst,Config,Estado,Nodos,CPU,Aceleracion,Eficiencia) :-
    Config\==clpfd_opt,
    exp_completa(Estado),CPU>0,
    exp_resultado(Modo,Inst,_,bt_ingenuo,BaseEstado,_,_,BaseN,_,BaseCPU,_),
    exp_completa(BaseEstado),BaseCPU>0,BaseN>0,!,
    Aceleracion is BaseCPU/CPU,Eficiencia is (BaseN-Nodos)/BaseN.
exp_ratios(_,_,_,_,_,_,na,na).
exp_csv_ratio(_,na) :- !.
exp_csv_ratio(S,N) :- format(S,'~6f',[N]).

/* Grafico SVG autonomo, sin JavaScript, red ni librerias graficas.
   x = log10(1+nodos); la misma escala se aplica a las 35 barras.
   Un contorno discontinuo indica corte y no una resolucion completa. */
exp_escribir_svg(Archivo, Modo) :-
    open(Archivo,write,S),
    catch(exp_svg(S,Modo),Error,(close(S),throw(Error))),close(S).
exp_svg(S,Modo) :-
    write(S,'<?xml version="1.0" encoding="UTF-8"?>'),nl(S),
    write(S,'<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="1320" viewBox="0 0 1200 1320" role="img" aria-labelledby="titulo descripcion">'),nl(S),
    write(S,'<title id="titulo">Nodos explorados por instancia y configuracion</title>'),nl(S),
    write(S,'<desc id="descripcion">Treinta y cinco corridas reales con limite de 5000 nodos. El eje horizontal usa log10 de uno mas el numero de nodos. Los contornos discontinuos identifican corridas que alcanzaron el limite.</desc>'),nl(S),
    write(S,'<rect width="1200" height="1320" fill="#f8fafc"/>'),nl(S),
    write(S,'<style>text{font-family:Arial,sans-serif;fill:#172033} .small{font-size:13px}.label{font-size:14px}.group{font-size:19px;font-weight:bold}.grid{stroke:#d6dce5;stroke-width:1}</style>'),nl(S),
    format(S,'<text x="32" y="42" font-size="27" font-weight="bold">Busqueda de horarios: modo ~a</text>~n',[Modo]),
    write(S,'<text x="32" y="70" class="label">Nodos explorados; limite comun de 5000 por corrida; escala log10(1 + nodos).</text>'),nl(S),
    write(S,'<text x="32" y="93" class="small">BT ingenuo sin simetria. Las otras configuraciones activan simetria. CLPFD opt exige costo minimo.</text>'),nl(S),
    exp_ejes(S,[0,10,100,1000,5000]),
    exp_instancias(Instancias),exp_svg_instancias(Instancias,S,Modo,145),
    write(S,'<text x="32" y="1284" class="small">Borde discontinuo = limite alcanzado. Menos nodos no implica menor tiempo: consultar CPU y pared en el CSV.</text>'),nl(S),
    write(S,'<text x="32" y="1307" class="small">Las instancias de 20, 40 y 80 sesiones son estructuradas: sus resultados no representan cualquier horario universitario.</text>'),nl(S),
    write(S,'</svg>'),nl(S).
exp_ejes(_,[]).
exp_ejes(S,[N|Ns]) :-
    exp_x_nodos(N,X),
    format(S,'<line x1="~2f" y1="122" x2="~2f" y2="1251" class="grid"/>~n',[X,X]),
    format(S,'<text x="~2f" y="117" text-anchor="middle" class="small">~d</text>~n',[X,N]),
    exp_ejes(S,Ns).
exp_x_nodos(N,X) :- X is 230+680*log(N+1)/log(5001).
exp_svg_instancias([],_,_,_).
exp_svg_instancias([Inst-_|Is],S,Modo,Y) :-
    exp_resultado(Modo,Inst,NS,_,_,_,_,_,_,_,_),!,
    format(S,'<text x="32" y="~d" class="group">~a (~d sesiones)</text>~n',[Y,Inst,NS]),
    exp_configuraciones(Configs),Inicio is Y+18,
    exp_svg_configs(Configs,S,Modo,Inst,Inicio),
    Siguiente is Y+224,exp_svg_instancias(Is,S,Modo,Siguiente).
exp_svg_configs([],_,_,_,_).
exp_svg_configs([Config|Cs],S,Modo,Inst,Y) :-
    exp_resultado(Modo,Inst,_,Config,Estado,_,_,Nodos,_,CPU,_),
    exp_color(Config,Color),exp_x_nodos(Nodos,Fin),Ancho is Fin-230,
    TextoY is Y+14,
    format(S,'<text x="215" y="~d" text-anchor="end" class="label">~a</text>~n',[TextoY,Config]),
    format(S,'<rect x="230" y="~d" width="~2f" height="18" rx="3" fill="~a"',[Y,Ancho,Color]),
    (Estado==limite -> write(S,' stroke="#172033" stroke-width="2" stroke-dasharray="5 3"') ; true),
    format(S,'><title>~a / ~a: ~d nodos; ~a; CPU ~3f s</title></rect>~n',[Inst,Config,Nodos,Estado,CPU]),
    format(S,'<text x="930" y="~d" class="small">~d | ~a | ~3f s</text>~n',[TextoY,Nodos,Estado,CPU]),
    Proximo is Y+26,exp_svg_configs(Cs,S,Modo,Inst,Proximo).
exp_color(bt_ingenuo,'#64748b').
exp_color(bt_mrv,'#2563eb').
exp_color(bt_grado,'#7c3aed').
exp_color(bt_demanda,'#c026d3').
exp_color(bt_lcv,'#0891b2').
exp_color(clpfd_ff,'#059669').
exp_color(clpfd_opt,'#d97706').
