-module(a_utils).

-export([getNowInMillis/0]).

getNowInMillis() ->
  {MegaSecs, Secs, MicroSecs} = now(),
  MegaSecs*1000000000 + Secs*1000 + MicroSecs/1000.
