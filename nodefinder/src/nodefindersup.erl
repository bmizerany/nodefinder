%% @hidden

-module (nodefindersup).
-behaviour (supervisor).

-export ([ start_link/2, init/1 ]).

%-=====================================================================-
%-                                Public                               -
%-=====================================================================-

start_link (Addr, Port) ->
  supervisor:start_link (?MODULE, [ Addr, Port ]).

init ([ Addr, Port ]) ->
  { ok,
    { { one_for_one, 3, 10 },
      [ { nodefindersrv,
          { nodefindersrv, start_link, [ Addr, Port ] },
          permanent,
          1000,
          worker,
          [ nodefindersrv ]
        }
      ]
    }
  }.
