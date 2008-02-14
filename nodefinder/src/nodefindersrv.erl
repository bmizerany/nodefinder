%% @doc Multicast Erlang node discovery protocol.
%% Listens on a multicast channel for node discovery requests and 
%% responds by connecting to the node.
%% @hidden
%% @end

-module (nodefindersrv).
-behaviour (gen_server).
-export ([ start_link/2, discover/0 ]).
-export ([ init/1,
           handle_call/3,
           handle_cast/2,
           handle_info/2,
           terminate/2,
           code_change/3]).

-record (state, { socket, addr, port }).

%-=====================================================================-
%-                                Public                               -
%-=====================================================================-

start_link (Addr, Port) ->
  gen_server:start_link ({ local, ?MODULE }, ?MODULE, [ Addr, Port ], []).

discover () ->
  gen_server:call (?MODULE, discover).

%-=====================================================================-
%-                         gen_server callbacks                        -
%-=====================================================================-

init ([ Addr, Port ]) ->
  process_flag (trap_exit, true),

  Opts = [ { active, true },
           { ip, Addr },
           { add_membership, { Addr, { 0, 0, 0, 0 } } },
           { multicast_loop, true },
           { reuseaddr, true },
           list ],

  { ok, Socket } = gen_udp:open (Port, Opts),

  { ok, discover (#state{ socket = Socket, addr = Addr, port = Port }) }.

handle_call (discover, _From, State) -> { reply, ok, discover (State) };
handle_call (_Request, _From, State) -> { noreply, State }.

handle_cast (_Request, State) -> { noreply, State }.

handle_info ({ udp, Socket, _IP, _InPortNo, Packet },
             State=#state{ socket = Socket }) ->
  { noreply, process_packet (Packet, State) };

handle_info (_Msg, State) -> { noreply, State }.

terminate (_Reason, State) ->
  gen_udp:close (State#state.socket),
  ok.

code_change (_OldVsn, State, _Extra) -> { ok, State }.

%-=====================================================================-
%-                               Private                               -
%-=====================================================================-

discover (State) ->
  ok = gen_udp:send (State#state.socket,
                     State#state.addr,
                     State#state.port,
                     "DISCOVER " ++ atom_to_list (node ())),
  State.

process_packet ("DISCOVER " ++ NodeName, State) -> 
  net_adm:ping (list_to_atom (NodeName)),
  State;
process_packet (_, State) -> State.
