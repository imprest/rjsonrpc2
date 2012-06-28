RJSONRPC2 - Restricted implementation of JSON-RPC 2.0 for Erlang
================================================================
Restricted implementation of the JSONRPC 2.0 spec
www.jsonrpc.org/specification

Only supports JSONRPC 2.0 requests with named parameters and needs a
interface/proplists of methods and parameter types that is used to
decode and validate jsonrpc requests.

Example
-------
Client jsonrpc-requests to be handled
<pre>
request1: {"jsonrpc": "2.0",
           "method": "login",
           "params": {"username": "foo",
                      "password": "bar"},
           "id": "_login"}

% For valid jsonrpc 2.0 request
response1: {"jsonrpc": "2.0",
            "result": "true"|"false",
            "id": "_login"}

% Notification (i.e. no Id provided) so not response required
request2: {"jsonrpc": "2.0",
           "method": "logout"}
</pre>

Sample misultin websocket loop to handle JSON-RPC 2.0 request 
and response (See misultin wiki on github to setup websocket server)
<pre>
% Define interface to handle JSON-RPC 2.0 requests
% Aside: parameter types can be the following atoms
%        binary|integer|float|boolean|list
interface() ->
  [{&lt;&lt;"login">>, [{params, [{&lt;&lt;"username">>, binary},
                  {&lt;&lt;"password">>, binary}]}]},
   {&lt;&lt;"logout">>, [{params, []}]}].

% Misultin websocket loop to handle browser json requests
ws_loop(Ws) ->
  receive
    {browser, Data} ->
      case rjsonrpc2:decode(list_to_binary(Data), interface()) of
        {&lt;&lt;"login">>, Params, Id} ->
          UserId = misultin_utility:get_key_value(&lt;&lt;"username">>, Params),
          Password = misultin_utility:get_key_value(&lt;&lt;"password">>, Params),
          case UserId =:= &lt;&lt;"foo">> andalso Password =:= &lt;&lt;"bar">> of
            true ->
              Response = rjsonrpc2:encode(true, Id),
              Ws:send(Response);
            false ->
              Response = rjsonrpc2:encode(false, Id),
              Ws:send(Response)
          end,
          ws_loop(Ws);
        {&lt;&lt;"logout">>, [], undefined} ->
          % logout user
          ws_loop(Ws);
        {error, JSONRPC_ERROR} ->
          Ws:send(jiffy:encode(JSONRPC_ERROR)),
          ws_loop(Ws);
        _ ->
          ws_loop(Ws)
      end;
    closed ->
      closed;
    _ ->
      ws_loop(Ws)
  end.
</pre>

