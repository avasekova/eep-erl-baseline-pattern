-module(a_utils).

-export([get/2, getNowInMillis/0]).

get(_Key, []) ->
  "";
get(Key, [{Key, Value}|_Rest]) ->
  Value;
get(Key, [_|Rest]) ->
  get(Key, Rest).


getNowInMillis() ->
  {MegaSecs, Secs, MicroSecs} = now(),
  MegaSecs*1000000000 + Secs*1000 + MicroSecs/1000.
