% Entrada del ejecutable nativo del banco: lanzar desde la raiz del proyecto.
:- initialization(exp_main_nativo).
exp_main_nativo :-
    catch((experimentos(nativo,'resultados/nativo.csv','resultados/nativo.svg') -> Codigo=0; Codigo=1),
          E,(format(user_error,'Error experimental: ~q~n',[E]),Codigo=1)),
    halt(Codigo).
