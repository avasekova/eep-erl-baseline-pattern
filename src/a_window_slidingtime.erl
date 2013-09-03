-module(a_window_slidingtime).

-include_lib("eep_erl.hrl").

-export([start/3, slide/4]).

start(AggModule, TimeInterval, Step) ->
  {ok, Pid} = gen_event:start_link(),
  WindowStart = a_utils:getNowInMillis(),
  Window = spawn(?MODULE, slide, [AggModule, Pid, WindowStart, Step]),
  spawn_link(a_timer, setAndRepeat, [Window, TimeInterval, Step]),
  Window.

slide(AggModule, Pid, WindowStart, Step) ->
  slide(AggModule, Pid, apply(AggModule, init, []), WindowStart, Step).

slide(AggModule, Pid, State, WindowStart, Step) ->
  receive
    timeout ->
      gen_event:notify(Pid, {emit, apply(AggModule, emit, [State])}),
      NewWindowStart = WindowStart + Step,
      NewState = apply(AggModule, compensate, [State, NewWindowStart]),
      slide(AggModule, Pid, NewState, NewWindowStart, Step);
    { push, Event } ->
      NewState = apply(AggModule, accumulate, [State, Event]),
      slide(AggModule, Pid, NewState, WindowStart, Step);
    { add_handler, Handler, Args } ->
      gen_event:add_handler(Pid, Handler, Args),
      slide(AggModule, Pid, State, WindowStart, Step);
    { delete_handler, Handler } ->
      gen_event:delete_handler(Pid, Handler),
      slide(AggModule, Pid, State, WindowStart, Step);


    { conjunction, Id} -> %TODO potom vymysliet inak... zatial si tu dam Id procesu, ktory chce dostavat vysledky z tohto okna
      NewState = apply(AggModule, conjunction, [State, Id]),
      slide(AggModule, Pid, NewState, WindowStart, Step);


    stop ->
      ok
  end.