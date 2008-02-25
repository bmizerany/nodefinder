%% @doc nodefinder+ec2nodefinder service.
%% @end

-module (combonodefinder).
-export ([ discover/0 ]).
-behaviour (application).
-export ([ start/0, start/2, stop/0, stop/1 ]).

%-=====================================================================-
%-                                Public                               -
%-=====================================================================-

%% @spec discover () -> ok
%% @doc Initiate a discovery request.  Nodes will respond 
%% synchronously (on EC2) or asynchronously (not on EC2) 
%% and therefore should not necessarily be considered added to the 
%% erlang node list subsequent to this call returning.
%% @end

discover () ->
  case is_ec2_host () of
    true -> ec2nodefindersrv:discover ();
    false -> nodefindersrv:discover ()
  end.

%-=====================================================================-
%-                        application callbacks                        -
%-=====================================================================-

%% @hidden

start () ->
  application:start (combonodefinder).

%% @hidden

start (Type, Args) ->
  case is_ec2_host () of
    true -> ec2nodefinder:start (Type, Args);
    false -> nodefinder:start (Type, Args)
  end.

%% @hidden

stop () ->
  application:stop (combonodefinder).

%% @hidden

stop (_State) ->
  ok.

%-=====================================================================-
%-                               Private                               -
%-=====================================================================-

is_ec2_host () ->
  Host = lists:last (string:tokens (atom_to_list (node ()), "@")),

  case lists:reverse (string:tokens (Host, ".")) of
    [ "com", "amazonaws" | _ ] -> true;
    _ -> false
  end.
