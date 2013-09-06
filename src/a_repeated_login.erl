-module(a_repeated_login).

-include_lib("eep_erl.hrl").

-behaviour(eep_aggregate).

%% aggregate behaviour.
-export([init/0]).
-export([accumulate/2]).
-export([compensate/2]).
-export([emit/1]).

-export([conjunction/2]).

-define(ATTEMPTS, 1000).

-record(a_repeated_login, {
  hostusers,    % struktura "groupby hosts,users", tj schematicky nieco ako [{Host1, [{User1, Count}, ...]}, ...]
  events = [],  % TODO pamatat si eventy v okne a nie tu
                 % problem: tu si pamatam a riesim len vyznamne (type = Login && success = false), v okne by bolo treba vsetky. vymysliet.
  conjunction = undefined %TODO vymysliet nejak radikalne inak (ale aspon to funguje)
}).

%TODO vycistit, premenovat na normalne nazvy
%TODO doc

init() ->
  #a_repeated_login{hostusers = dict:new()}.

accumulate(State, Event) ->
  {"type", Type} = lists:keyfind("type", 1, Event),
  case Type of
    "org.ssh.Daemon#Login" ->
      {"_", Payload} = lists:keyfind("_", 1, Event),
      {"success", Success} = lists:keyfind("success", 1, Payload),
      case Success of
        true ->
          %io:format("Not interested in successful events. ~n"),
          State;
        false ->
          NewEvents = State#a_repeated_login.events ++ [Event], %prave v tom [Event] bola chyba, tak nieze to zase zmazem
          NewState = State#a_repeated_login{events = NewEvents},
          {"host", Host} = lists:keyfind("host", 1, Event),
          {"user", User} = lists:keyfind("user", 1, Payload),
          case dict:is_key(Host, NewState#a_repeated_login.hostusers) of
            true ->
              UserCounts = dict:fetch(Host, NewState#a_repeated_login.hostusers),
              case dict:is_key(User, UserCounts) of
                true ->
                  Count = dict:fetch(User, UserCounts),
                  NewUserCounts = dict:store(User, Count + 1, UserCounts);
                false ->
                  NewUserCounts = dict:store(User, 1, UserCounts)
              end;
            false ->
              UserCounts = dict:new(),
              NewUserCounts = dict:store(User, 1, UserCounts)
          end,
          NewHosts = dict:store(Host, NewUserCounts, NewState#a_repeated_login.hostusers),
          NewState#a_repeated_login{hostusers = NewHosts}
      end;
    _ ->
      %io:format("Not interested in this type of event: ~s~n", [Type]),
      State
  end.

compensate(State, WindowStart) -> %TODO drzat si events v okne a sem len posielat tie, co vypadli z okna
  {RemainingEvents, ToDealWith} = lists:partition(fun(E) -> {"occurrenceTime", Value} = lists:keyfind("occurrenceTime", 1, E), Value >= WindowStart end, State#a_repeated_login.events),
  NewHostUsers = decreaseCounters(ToDealWith, State#a_repeated_login.hostusers),
  State#a_repeated_login{hostusers = NewHostUsers, events = RemainingEvents}.

emit(State) ->
  Result = filterAndToList(dict:to_list(State#a_repeated_login.hostusers)),
  case State#a_repeated_login.conjunction of
    undefined ->
      ok; %Result;
    Pid ->
      Pid ! {a_repeated_login, Result},
      ok %Result
  end.

conjunction(State, Pid) ->
  State#a_repeated_login{conjunction = Pid}.


decreaseCounters([], HostUsers) ->
  HostUsers;
decreaseCounters([E|Events], HostUsers) ->
  {"_", Payload} = lists:keyfind("_", 1, E),
  {"host", Host} = lists:keyfind("host", 1, E),
  {"user", User} = lists:keyfind("user", 1, Payload),
  UserCounts = dict:fetch(Host, HostUsers),
  Count = dict:fetch(User, UserCounts),
  case Count of
    1 ->
      NewUserCounts = dict:erase(User, UserCounts);
    _ ->
      NewUserCounts = dict:store(User, Count - 1, UserCounts)
  end,
  case dict:size(NewUserCounts) of
    0 ->
      NewHostsUsers = dict:erase(Host, HostUsers);
    _ ->
      NewHostsUsers = dict:store(Host, NewUserCounts, HostUsers)
  end,
  decreaseCounters(Events, NewHostsUsers).

filterAndToList(HostUsers) ->
  filterAndToList(HostUsers, []).

filterAndToList([], Lists) ->
  Lists;
filterAndToList([{Host, UserCounts}|HostUsers], Lists) ->
  CountOverATTEMPTS = [{User, Count} || {User, Count} <- dict:to_list(UserCounts), Count > ?ATTEMPTS],
  if
    length(CountOverATTEMPTS) > 0 ->
      filterAndToList(HostUsers, [Host|Lists]);%ak treba debug vypis, tak: filterAndToList(HostUsers, [{Host, CountOverATTEMPTS}|Lists]);
    length(CountOverATTEMPTS) == 0 ->
      filterAndToList(HostUsers, Lists)
  end.