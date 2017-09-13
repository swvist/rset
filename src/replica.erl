-module(replica).
-author("Vipin Nair <swvist@gmail.com>").

-include("rset.hrl").
-behaviour(gen_server).

%% API
-export([create/1,
         add/2,
         delete/2,
         elements/1]).

% Internal API
-export([start_link/2]).

%% Gen server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).


%% -----------------------------------------------------------------------------

create(AllReplicas) ->
    rset_sup:create_replica(AllReplicas).


start_link(ThisReplica, AllReplicas) ->
    gen_server:start_link({local, ThisReplica}, ?MODULE,
                          [ThisReplica, AllReplicas], []).

add(Replica, Value) ->
    gen_server:call(Replica, {add, Value}).

delete(Replica, Value) ->
    gen_server:call(Replica, {delete, Value}).

elements(Replica) ->
    gen_server:call(Replica, elements).

init([ThisReplica, AllReplicas]) ->
    {ok, rset:init(ThisReplica, AllReplicas)}.

handle_call({add, {_, _, _}=Element}, _From, State0) ->
    {Element, State} = rset:add(Element, State0),
    {reply, {ok, Element}, State};

handle_call({add, Value}, _From,
            #rset{repinfo = {_, OtherReplicas, _}}=State0) ->
    {Element, State} = rset:add(Value, State0),
    [add(Replica, Element) || Replica <- OtherReplicas],
    {reply, {ok, Element}, State};

handle_call({delete, #{}=DelIVVMap}, _From, State0) ->
    {Element, State} = rset:delete(DelIVVMap, State0),
    {reply, {ok, Element}, State};

handle_call({delete, Value}, _From,
            #rset{repinfo = {_, OtherReplicas, _}}=State0) ->
    {DelIVVMap, State} = rset:delete(Value, State0),
    [delete(Replica, DelIVVMap) || Replica <- OtherReplicas],
    {reply, {ok, DelIVVMap}, State};

handle_call(elements, _From, State) ->
    Elements = rset:elements(State),
    {reply, {ok, Elements}, State};

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
