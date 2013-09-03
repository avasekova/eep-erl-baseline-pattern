-module(a_timer).

-export([setAndRepeat/3]).

setAndRepeat(Client, Time, Step) -> receive
                                    after Time ->
                                      Client ! timeout,
                                      step(Client, Step)
                                    end.

step(Client, Step) -> receive
                      after Step ->
                        Client ! timeout,
                        step(Client, Step)
                      end.
