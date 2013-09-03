-module(a_repeatedlogin_and_multiplehosts).

-export([start/0, receiveMessages/1]).

-record(rec, {
  loginSuspects = [],
  hostsSuspects = []
}).

start() ->
  State = #rec{},
  spawn(?MODULE, receiveMessages, [State]).

receiveMessages(State) ->
  receive
    {a_repeated_login, Suspects} ->
      %problem: neaktualizuje sa este to druhe okno, a vypisu sa zle vysledky. zatial riesene tak, ze to vypise aj druhe okno, a tie
      % druhe vysledky sa povazuju za spravne
      NewState = State#rec{loginSuspects = Suspects},
      Attackers = lists:filter(fun(X) -> lists:member(X,NewState#rec.loginSuspects) end, NewState#rec.hostsSuspects),
      io:format("--- Vysledni podozrivi (~w x ~w): ~p~n", [length(NewState#rec.loginSuspects), length(NewState#rec.hostsSuspects), Attackers]),
      receiveMessages(NewState);
    {a_multiple_hosts, Suspects} ->
      NewState = State#rec{hostsSuspects = Suspects},
      Attackers = lists:filter(fun(X) -> lists:member(X,NewState#rec.loginSuspects) end, NewState#rec.hostsSuspects),
      io:format("--- Vysledni podozrivi (pravdepodobnejsi) (~w x ~w): ~p~n", [length(NewState#rec.loginSuspects), length(NewState#rec.hostsSuspects), Attackers]),
      receiveMessages(NewState);

    stop ->
      ok;
    _Message ->
      receiveMessages(State)
  end.