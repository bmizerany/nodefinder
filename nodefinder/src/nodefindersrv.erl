%% @doc Multicast Erlang node discovery protocol.
%% Listens on a multicast channel for node discovery requests and 
%% responds by connecting to the node.
%% @hidden
%% @end

-module (nodefindersrv).
-behaviour (gen_server).
-export ([ start_link/2, start_link/3, discover/0 ]).
-export ([ init/1,
           handle_call/3,
           handle_cast/2,
           handle_info/2,
           terminate/2,
           code_change/3]).

-oldrecord (state).

-record (state, { socket, addr, port }).
-record (statev2, { sendsock, recvsock, addr, port }).

%-=====================================================================-
%-                                Public                               -
%-=====================================================================-

start_link (Addr, Port) ->
  start_link (Addr, Port, 1).

start_link (Addr, Port, Ttl) ->
  gen_server:start_link ({ local, ?MODULE }, ?MODULE, [ Addr, Port, Ttl ], []).

discover () ->
  gen_server:call (?MODULE, discover).

%-=====================================================================-
%-                         gen_server callbacks                        -
%-=====================================================================-

init ([ Addr, Port, Ttl ]) ->
  process_flag (trap_exit, true),

  Opts = [ { active, true },
           { ip, Addr },
           { add_membership, { Addr, { 0, 0, 0, 0 } } },
           { multicast_loop, true },
           { reuseaddr, true },
           list ],

  { ok, RecvSocket } = gen_udp:open (Port, Opts),

  { ok, discover (#statev2{ recvsock = RecvSocket,
                            sendsock = send_socket (Ttl),
                            addr = Addr,
                            port = Port }) }.

handle_call (discover, _From, State) -> { reply, ok, discover (State) };
handle_call (_Request, _From, State) -> { noreply, State }.

handle_cast (_Request, State) -> { noreply, State }.

handle_info ({ udp, Socket, IP, InPortNo, Packet },
             State=#statev2{ recvsock = Socket }) ->
  { noreply, process_packet (Packet, IP, InPortNo, State) };

handle_info (_Msg, State) -> { noreply, State }.

terminate (_Reason, State = #statev2{}) ->
  gen_udp:close (State#statev2.recvsock),
  gen_udp:close (State#statev2.sendsock),
  ok.

code_change (_OldVsn, State = #state{}, _Extra) -> 
  NewState = #statev2{ recvsock = State#state.socket,
                       sendsock = send_socket (1),
                       addr = State#state.addr,
                       port = State#state.port },
  { ok, NewState };
code_change (_OldVsn, State, _Extra) -> 
  { ok, State }.

%-=====================================================================-
%-                               Private                               -
%-=====================================================================-

discover (State) ->
  NodeString = atom_to_list (node ()),
  Mac = mac (NodeString),
  Message = [ "DISCOVERV2 ", Mac, " ", NodeString ],
  ok = gen_udp:send (State#statev2.sendsock,
                     State#statev2.addr,
                     State#statev2.port,
                     Message),
  State.

mac (NodeString) ->
  crypto:sha_mac (erlang:term_to_binary (erlang:get_cookie ()), NodeString).

process_packet ("DISCOVER " ++ NodeName, IP, InPortNo, State) -> 
  error_logger:warning_msg ("old DISCOVER packet from ~p (~p:~p) ~n", 
                            [ NodeName,
                              IP,
                              InPortNo ]),
  State;
process_packet ("DISCOVERV2 " ++ Rest, IP, InPortNo, State) -> 
  % Falling a mac is not really worth logging, since having multiple
  % cookies on the network is one way to prevent crosstalk.  However
  % the packet should always have the right structure.

  try
    <<Mac:20/binary, " ", NodeString/binary>> = list_to_binary (Rest),
    try
      Mac = mac (NodeString),
      net_adm:ping (list_to_atom (binary_to_list (NodeString)))
    catch
      _ : _ ->
        ok
    end
  catch
    _ : _ ->
      error_logger:warning_msg ("bad DISCOVERV2 ~p (from ~p:~p)~n", 
                                [ list_to_binary (Rest),
                                  IP,
                                  InPortNo ])
  end,

  State;
process_packet (_Packet, _IP, _InPortNo, State) -> 
  State.

send_socket (Ttl) ->
  SendOpts = [ { ip, { 0, 0, 0, 0 } },
               { multicast_ttl, Ttl }, 
               { multicast_loop, true } ],

  { ok, SendSocket } = gen_udp:open (0, SendOpts),

  SendSocket.
