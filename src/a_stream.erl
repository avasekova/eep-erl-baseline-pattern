-module(a_stream).

-export([start/0, run/1, forwardToAllWindows/2, resendMessages/1]).

-record(a_stream, {
  windows = []
}).

% odteraz uz nikdy nepustat okna same, vzdy ich zaregistrovat sem. sem maju chodit udalosti a odtialto sa rozposlu navesanym oknam.
start() ->
  Record = #a_stream{},
  ServerId = spawn(?MODULE, run, [Record]),

  register(server, spawn(?MODULE, resendMessages, [ServerId])),

  ServerId.


resendMessages(Pid) ->
  receive
    {Sender, Event} ->
      %io:format("Got a message: ~w~n", [Event]),
      Sender ! Event, %poslat to pre kontrolu naspat
      Pid ! {push, Event}, %preposli, nechaj spracovat run/1
      resendMessages(Pid);
    shutdown -> ok
  end.


run(Record) -> receive
                 stop ->
                   forwardToAllWindows(stop, Record#a_stream.windows),
                   ok;
                 getWindows ->
                   io:format("Windows: ~p~n", [Record#a_stream.windows]),
                   run(Record);
                 {addWindow, WindowID} ->
                   Windows = Record#a_stream.windows,
                   Updated = Record#a_stream{windows = [WindowID|Windows]},
                   run(Updated);
                 {removeWindow, WindowID} ->
                   Updated = lists:delete(WindowID, Record#a_stream.windows),
                   run(Updated);
                 Msg ->
                   forwardToAllWindows(Msg, Record#a_stream.windows),
                   run(Record)
               end.

forwardToAllWindows(_, []) -> ok;
forwardToAllWindows(Msg, [W|Rest]) -> W ! Msg,
                                      forwardToAllWindows(Msg, Rest).