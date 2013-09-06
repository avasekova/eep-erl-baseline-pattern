-module(a_multiple_hosts).

-include_lib("eep_erl.hrl").

-behaviour(eep_aggregate).

%% aggregate behaviour.
-export([init/0]).
-export([accumulate/2]).
-export([compensate/2]).
-export([emit/1]).

-export([conjunction/2]).

-define(HOSTS, 4).

-record(a_multiple_hosts, {
  hosts,   %struktura v tvare [{Host1, [SourceHost1, SourceHost2, ...]}, ...]
  events = [], %TODO
  conjunction = undefined %TODO
}).

init() ->
  #a_multiple_hosts{hosts = dict:new()}.

accumulate(State, Event) ->
  {"type", Type} = lists:keyfind("type", 1, Event),
  case Type of
    "org.ssh.Daemon#Login" ->
      {"host", Host} = lists:keyfind("host", 1, Event),
      {"_", Payload} = lists:keyfind("_", 1, Event),
      {"sourceHost", SourceHost} = lists:keyfind("sourceHost", 1, Payload),
      case dict:is_key(Host, State#a_multiple_hosts.hosts) of
        true ->
          SourceHostss = dict:fetch(Host, State#a_multiple_hosts.hosts),
          case sets:is_element(SourceHost, SourceHostss) of
            true ->
              State;
            false ->
              NewSourceHostss = sets:add_element(SourceHost, SourceHostss),
              NewHosts = dict:store(Host, NewSourceHostss, State#a_multiple_hosts.hosts),
              NewState = State#a_multiple_hosts{hosts = NewHosts},

              NewEvents = NewState#a_multiple_hosts.events ++ [Event], %prave v tom [Event] bola chyba, tak nieze to zase zmazem
              NewState#a_multiple_hosts{events = NewEvents}
          end;
        false ->
          SourceHostss = sets:new(),
          NewSourceHostss = sets:add_element(SourceHost, SourceHostss),
          NewHosts = dict:store(Host, NewSourceHostss, State#a_multiple_hosts.hosts),
          NewState = State#a_multiple_hosts{hosts = NewHosts},

          NewEvents = NewState#a_multiple_hosts.events ++ [Event], %neopravovat, je to dobre
          NewState#a_multiple_hosts{events = NewEvents}
      end;
    _ ->
      %io:format("Not interested in this type of event: ~s~n", [Type]),
      State
  end.

compensate(State, WindowStart) ->
  {NewEvents, ToDealWith} = lists:partition(fun(E) -> {"occurrenceTime", Value} = lists:keyfind("occurrenceTime", 1, E), Value >= WindowStart end, State#a_multiple_hosts.events),
  NewHosts = deleteOld(ToDealWith, State#a_multiple_hosts.hosts),
  State#a_multiple_hosts{hosts = NewHosts, events = NewEvents}.

emit(State) ->
  Result = [Host || {Host, SourceHosts} <- dict:to_list(State#a_multiple_hosts.hosts), sets:size(SourceHosts) > ?HOSTS],
  case State#a_multiple_hosts.conjunction of
    undefined ->
      ok; %Result;
    Pid ->
      Pid ! {a_multiple_hosts, Result},
      ok %Result
  end.


conjunction(State, Pid) ->
  State#a_multiple_hosts{conjunction = Pid}.


deleteOld([], Hostss) ->
  Hostss;
deleteOld([E|Events], Hostss) ->
  {"host", Host} = lists:keyfind("host", 1, E),
  {"_", Payload} = lists:keyfind("_", 1, E),
  {"sourceHost", SourceHost} = lists:keyfind("sourceHost", 1, Payload),

  case dict:is_key(Host, Hostss) of
    true ->
      SourceHostss = dict:fetch(Host, Hostss),
      case sets:is_element(SourceHost, SourceHostss) of
        true ->
          NewSourceHostss = sets:del_element(SourceHost, SourceHostss),
          case sets:size(NewSourceHostss) of
            0 ->
              NewHostss = dict:erase(Host, Hostss);
            _ ->
              NewHostss = dict:store(Host, NewSourceHostss, Hostss)
          end,
          deleteOld(Events, NewHostss);
        false ->
          deleteOld(Events, Hostss)
      end;
    false ->
      deleteOld(Events, Hostss)
  end.
