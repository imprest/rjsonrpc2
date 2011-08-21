RJSONRPC2 - Restricted implementation of JSON-RPC 2.0 for Erlang
================================================================
Restricted implementation of the JSONRPC 2.0 spec
http://groups.google.com/group/json-rpc/web/json-rpc-2-0

Only supports JSONRPC 2.0 requests with named parameters and needs a
interface/proplists of methods and parameter types that is used to
decoded and validate jsonrpc requests.

Example
-------
Client jsonrpc-requests to be handled
```
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
```

Sample misultin websocket loop to handle JSON-RPC 2.0 request 
and response (See misultin wiki on github to setup websocket server)
```erlang
% Define interface to handle JSON-RPC 2.0 requests
% Aside: parameter types can be the following atoms
%				 binary|integer|float|boolean|list
interface() ->
  [{<<"login">>, [{<<"username">>, binary},
                  {<<"password">>, binary}]},
   {<<"logout">>, []}].

% Misultin websocket loop to handle browser json requests
ws_loop(Ws) ->
  receive
    {browser, Data} ->
      case rjsonrpc2:decode(list_to_binary(Data), interface()) of
        {<<"login">>, Params, Id} ->
          UserId = misultin_utility:get_key_value(<<"username">>, Params),
          Password = misultin_utility:get_key_value(<<"password">>, Params),
          case UserId =:= <<"foo">> andalso Password =:= <<"bar">> of
            true ->
              Response = rjsonrpc2:encode(true, Id),
              Ws:send(Response);
            false ->
              Response = rjsonrpc2:encode(false, Id),
              Ws:send(Response)
          end,
          ws_loop(Ws);
        {<<"logout">>, [], undefined} ->
          % logout user
          ws_loop(Ws);
        {error, Msg} ->
          Ws:send(jiffy:encode(Msg)),
          ws_loop(Ws);
        _ ->
          ws_loop(Ws)
      end;
    closed ->
      closed;
    _ ->
      ws_loop(Ws)
  end.
```

