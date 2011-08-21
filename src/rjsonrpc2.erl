%% @author Hardik Varia <hardikvaria@gmail.com>
%% @copyright Copyright (c) 2011, Hardik Varia <hardikvaria@gmail.com>
%%            See LICENSE file for more information.

%% @doc Restricted implementation of the JSONRPC 2.0 spec
%%      <a href="http://groups.google.com/group/json-rpc/web/json-rpc-2-0">
%%      <tt>http://groups.google.com/group/json-rpc/web/json-rpc-2-0</tt></a>
%%
%%      Only supports JSONRPC 2.0 requests with named parameters and needs a
%%      interface (proplists) of methods and parameter types that can decoded
%%      as valid jsonrpc requests. See README for more information.

-module(rjsonrpc2).
-author('hardikvaria@gmail.com').

% API
-export([decode/2, encode/2, construct_response/2]).

% Macros
-define(JSONRPC_VERSION, <<"2.0">>).
-define(JSONRPC2, {<<"jsonrpc">>, ?JSONRPC_VERSION}).
-define(ERROR_OBJECT(CODE, MSG), {[ ?JSONRPC2
                                  , {<<"error">>, {[ {<<"code">>, CODE}
                                                   , {<<"message">>, MSG}]}}
                                  , {<<"id">>, null}]}).
-define(RESPONSE_OBJECT(RESULT, ID), {[ ?JSONRPC2
                                      , {<<"result">>, RESULT}
                                      , {<<"id">>, ID}]}).

% Error code for -32768 to -32000 are reserved for pre-defined errors by the spec.
% Predefined error codes.
-define(PARSE_ERROR     , {error, ?ERROR_OBJECT(-32700, <<"Server unable to parse JSON.">>)}).
-define(INVALID_REQUEST , {error, ?ERROR_OBJECT(-32600, <<"Not valid JSON-RPC 2.0.">>)}).
-define(METHOD_NOT_FOUND, {error, ?ERROR_OBJECT(-32601, <<"Method not found.">>)}).
-define(INVALID_PARAMS  , {error, ?ERROR_OBJECT(-32602, <<"Invalid params.">>)}).
% -define(INTERNAL_ERROR, ?ERROR_OBJECT(-32603, <<"Internal error.">>)).
% -32099 to -32000 for Server error i.e. Reserved for implementation-defined server-errors.

encode(Result, Id) -> jiffy:encode(construct_response(Result, Id)).
construct_response(Result, Id) -> ?RESPONSE_OBJECT(Result, Id).

decode(EncodedJson, Interface) ->
  case is_json(EncodedJson) of % Test if request is valid json
    {Json}  ->
      case is_jsonrpc2(Json) of % Test if the request is valid jsonrpc2.0 request
        true  -> decode2(Json, Interface);
        false -> ?INVALID_REQUEST
      end;
    false  -> ?PARSE_ERROR
  end.
% Test request object is calling a valid Method
decode2(Json, Interface) ->
  Id = get_key_value(<<"id">>, Json),
  Method = get_key_value(<<"method">>, Json),
  case is_valid_method(Method, Interface) of
    true  -> decode3(Id
      , Method
      , get_key_value(<<"params">>, Json)
      , Interface);
    false -> ?METHOD_NOT_FOUND
  end.
% Check if request params match for method call
decode3(Id, Method, Params, Interface) ->
  case is_valid_params(Method, Params, Interface) of
    true ->
      case Params =:= [] orelse
           Params =:= undefined orelse
           Params =:= null of
        false -> {ParamList} = Params, {Method, ParamList, Id};
        true -> {Method, [], Id}
      end;
    false -> ?INVALID_PARAMS
  end.

% Check if it is valid json and only accept json objects
is_json(EncodedJson) ->
  try jiffy:decode(EncodedJson) of
    {JsonRPC} -> {JsonRPC};
    _Error -> false
  catch
    _Class:_Term -> false
  end.

% Check if request is a valid jsonrpc2 request
is_jsonrpc2(Json) ->
  case ?JSONRPC_VERSION =:= get_key_value(<<"jsonrpc">>, Json) of
    true -> check_method(Json);
    false -> false
  end.
check_method(Json) ->
  case is_binary(get_key_value(<<"method">>, Json)) of
    true -> check_params(Json);
    false -> false
  end.
check_params(Json) ->
  check_id(Json).
check_id(Json) ->
  Id = get_key_value(<<"id">>, Json),
  case Id of
    undefined -> true; % Notification i.e. client does not require a response to method
    Id -> 
      case is_binary(Id) orelse is_integer(Id) of
        true -> true;
        false -> false
      end
  end.

% Check if method requested is in available server methods
is_valid_method(Method, Interface) ->
  undefined =/= get_key_value(Method, Interface).

% Check if params are correct for the requested method
is_valid_params(Method, JsonParams, Interface) ->
  ParamsTypeList = get_key_value(Method, Interface),
  case JsonParams of
    undefined -> [] =:= ParamsTypeList;
    [] -> ParamsTypeList =:= JsonParams;
    {ParamsList} ->
      T = [ {Param, Value, ParamsTypeList} || {Param, Value} <- ParamsList],
      lists:all(fun(X) -> is_valid_param(X) end, T);
    null -> [] =:= ParamsTypeList
  end.

is_valid_param({Param, Value, ParamsTypeList}) ->
  case {get_key_value(Param, ParamsTypeList), Value} of
    {_Type, null} -> true;
    {binary,  _} -> is_binary(Value);
    {integer, _} -> is_integer(Value);
    {float,   _} -> is_float(Value);
    {boolean, _} -> is_boolean(Value);
    {list,    _} -> is_list(Value);
    {_Type, _Value} -> false
  end.

get_key_value(Key, List) ->
  case lists:keyfind(Key, 1, List) of
    false -> undefined;
    {_K, Value} -> Value
  end.

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

test_interface() ->
  [{<<"test_zero_params">>, []},
   {<<"test_invalid_param_type">>, [{<<"invalid_param">>, integer}]},
   {<<"test_invalid_param_type2">>, [{<<"invalid_param2">>, "invalid"}]},
   {<<"test_param_types">>,
     [{<<"test_binary">>  , binary},
      {<<"test_integer">> , integer},
      {<<"test_float">>   , float},
      {<<"test_boolean">> , boolean},
      {<<"test_null">>    , null},
      {<<"test_list">>    , list}]}].

test_invalid_request() ->
  {[{<<"jsonrpc">>, <<"1.5">>}]}.
test_invalid_method() ->
  {[{<<"jsonrpc">>, <<"2.0">>},
    {<<"method">>, <<"invalidMethod">>}]}.
test_invalid_method2() ->
  {[{<<"jsonrpc">>, <<"2.0">>},
    {<<"method">>, 1}]}.
test_invalid_param() ->
  {[{<<"jsonrpc">>, <<"2.0">>},
    {<<"method">>, <<"test_invalid_param_type">>},
    {<<"params">>, {[{<<"invalid_param">>, <<"invalid">>}]}}]}.
test_invalid_param2() ->
  {[{<<"jsonrpc">>, <<"2.0">>},
    {<<"method">>, <<"test_invalid_param_type2">>},
    {<<"params">>, {[{<<"invalid_param2">>, <<"invalid">>}]}}]}.

test_zero_params() ->
  {[{<<"jsonrpc">>, <<"2.0">>},
    {<<"method">>, <<"test_zero_params">>}]}.
test_empty_params() ->
  {[{<<"jsonrpc">>, <<"2.0">>},
    {<<"method">>, <<"test_zero_params">>},
    {<<"params">>, []}]}.
test_null_params() ->
  {[{<<"jsonrpc">>, <<"2.0">>},
    {<<"method">>, <<"test_zero_params">>},
    {<<"params">>, null}]}.
decoded_test_zero_params() ->
  {<<"test_zero_params">>, [], undefined}.

test_valid_id() ->
  {[{<<"jsonrpc">>, <<"2.0">>},
    {<<"method">>, <<"test_zero_params">>},
    {<<"id">>, 1}]}.
decoded_test_valid_id() ->
  {<<"test_zero_params">>, [], 1}.

test_valid_id2() ->
  {[{<<"jsonrpc">>, <<"2.0">>},
    {<<"method">>, <<"test_zero_params">>},
    {<<"id">>, <<"_test">>}]}.
decoded_test_valid_id2() ->
  {<<"test_zero_params">>, [], <<"_test">>}.

test_invalid_id() ->
  {[{<<"jsonrpc">>, <<"2.0">>},
    {<<"method">>, <<"test_zero_params">>},
    {<<"id">>, true}]}.

test_param_types() ->
  {[{<<"jsonrpc">>, <<"2.0">>},
    {<<"method">>, <<"test_param_types">>},
    {<<"params">>, {[{<<"test_binary">>  , <<"hello">>},
                     {<<"test_integer">> , -1},
                     {<<"test_float">>   , -0.1},
                     {<<"test_boolean">> , false},
                     {<<"test_null">>    , null},
                     {<<"test_list">>    , [1,2,3]}]}}]}.
decoded_test_param_types() ->
  {<<"test_param_types">>,
   [{<<"test_binary">>  , <<"hello">>},
    {<<"test_integer">> , -1},
    {<<"test_float">>   , -0.1},
    {<<"test_boolean">> , false},
    {<<"test_null">>    , null},
    {<<"test_list">>    , [1,2,3]}],
   undefined}.

parse_error_test() ->
  ?assert(?PARSE_ERROR =:=
    decode([], [])).

valid_request_but_not_json_object_test() ->
  ?assert(?PARSE_ERROR =:=
    decode(jiffy:encode([1,2]), [])).

invalid_request_test() ->
  ?assert(?INVALID_REQUEST =:=
    decode(jiffy:encode(test_invalid_request()), [])).

method_not_found_test() ->
  ?assert(?METHOD_NOT_FOUND =:=
    decode(jiffy:encode(test_invalid_method()), test_interface())).

method_not_binary_test() ->
  ?assert(?INVALID_REQUEST =:=
    decode(jiffy:encode(test_invalid_method2()), test_interface())).

invalid_params_test() ->
  ?assert(?INVALID_PARAMS =:=
    decode(jiffy:encode(test_invalid_param()), test_interface())).

invalid_params_2_test() ->
  ?assert(?INVALID_PARAMS =:=
    decode(jiffy:encode(test_invalid_param2()), test_interface())).

valid_request_with_zero_params_test() ->
  ?assert(decoded_test_zero_params() =:=
    decode(jiffy:encode(test_zero_params()), test_interface())).

valid_request_with_empty_params_test() ->
  ?assert(decoded_test_zero_params() =:=
    decode(jiffy:encode(test_empty_params()), test_interface())).

valid_request_with_null_params_test() ->
  ?assert(decoded_test_zero_params() =:=
    decode(jiffy:encode(test_null_params()), test_interface())).

valid_request_with_valid_id_test() ->
  ?assert(decoded_test_valid_id() =:=
    decode(jiffy:encode(test_valid_id()), test_interface())).

valid_request_with_valid_id2_test() ->
  ?assert(decoded_test_valid_id2() =:=
    decode(jiffy:encode(test_valid_id2()), test_interface())).

invalid_id_test() ->
  ?assert(?INVALID_REQUEST =:=
    decode(jiffy:encode(test_invalid_id()), test_interface())).

valid_request_param_types_test() ->
  ?assert(decoded_test_param_types() =:=
    decode(jiffy:encode(test_param_types()), test_interface())).

encode_reponse_test() -> 
  ?assert(jiffy:encode(construct_response({[{<<"result">>, true}]}, 1)) =:= 
    encode({[{<<"result">>, true}]}, 1)).

-endif.

