%%
%% Copyright (c) 2015-2016 Christopher Meiklejohn.  All Rights Reserved.
%% Copyright (c) 2007-2012 Basho Technologies, Inc.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

%% @doc GSet CRDT: grow only set.
%%
%% @reference Paulo Sérgio Almeida, Ali Shoker, and Carlos Baquero
%%      Delta State Replicated Data Types (2016)
%%      [http://arxiv.org/pdf/1603.01529v1.pdf]
%%
%% @reference Carlos Baquero
%%      delta-enabled-crdts C++ library
%%      [https://github.com/CBaquero/delta-enabled-crdts]

-module(state_gset).
-author("Vitor Enes Duarte <vitorenesduarte@gmail.com>").

-behaviour(type).
-behaviour(state_type).

-define(TYPE, ?MODULE).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-export([new/0, new/1]).
-export([mutate/3, delta_mutate/3, merge/2]).
-export([query/1, equal/2, is_bottom/1, is_inflation/2, is_strict_inflation/2]).
-export([join_decomposition/1]).

-export_type([state_gset/0, delta_state_gset/0, state_gset_op/0]).

-opaque state_gset() :: {?TYPE, payload()}.
-opaque delta_state_gset() :: {?TYPE, {delta, payload()}}.
-type delta_or_state() :: state_gset() | delta_state_gset().
-type payload() :: ordsets:ordset(any()).
-type element() :: term().
-type state_gset_op() :: {add, element()}.

%% @doc Create a new, empty `state_gset()'
-spec new() -> state_gset().
new() ->
    {?TYPE, ordsets:new()}.

%% @doc Create a new, empty `state_gset()'
-spec new([term()]) -> state_gset().
new([]) ->
    new().

%% @doc Mutate a `state_gset()'.
-spec mutate(state_gset_op(), type:id(), state_gset()) ->
    {ok, state_gset()}.
mutate(Op, Actor, {?TYPE, _GSet}=CRDT) ->
    state_type:mutate(Op, Actor, CRDT).

%% @doc Delta-mutate a `state_gset()'.
%%      The first argument can only be `{add, element()}'.
%%      The second argument is the replica id (unused).
%%      The third argument is the `state_gset()' to be inflated.
%%      Returns a `state_gset()' delta which is a new `state_gset()'
%%      with only one element - the element to be added to
%%      the set. If the element is already in the set
%%      the resulting delta will be an empty `state_gset()'.
-spec delta_mutate(state_gset_op(), type:id(), state_gset()) ->
    {ok, delta_state_gset()}.
delta_mutate({add, Elem}, _Actor, {?TYPE, GSet}) ->
    Delta = case ordsets:is_element(Elem, GSet) of
        true ->
            ordsets:new();
        false ->
            ordsets:add_element(Elem, ordsets:new())
    end,
    {ok, {?TYPE, {delta, Delta}}}.

%% @doc Returns the value of the `state_gset()'.
%%      This value is a set with all the elements in the `state_gset()'.
-spec query(state_gset()) -> sets:set(element()).
query({?TYPE, GSet}) ->
    sets:from_list(GSet).

%% @doc Merge two `state_gset()'.
%%      The result is the set union of both sets in the
%%      `state_gset()' passed as argument.
-spec merge(delta_or_state(), delta_or_state()) -> delta_or_state().
merge({?TYPE, {delta, Delta1}}, {?TYPE, {delta, Delta2}}) ->
    {?TYPE, DeltaGroup} = ?TYPE:merge({?TYPE, Delta1}, {?TYPE, Delta2}),
    {?TYPE, {delta, DeltaGroup}};
merge({?TYPE, {delta, Delta}}, {?TYPE, CRDT}) ->
    merge({?TYPE, Delta}, {?TYPE, CRDT});
merge({?TYPE, CRDT}, {?TYPE, {delta, Delta}}) ->
    merge({?TYPE, Delta}, {?TYPE, CRDT});
merge({?TYPE, GSet1}, {?TYPE, GSet2}) ->
    GSet = ordsets:union(GSet1, GSet2),
    {?TYPE, GSet}.

%% @doc Equality for `state_gset()'.
-spec equal(state_gset(), state_gset()) -> boolean().
equal({?TYPE, GSet1}, {?TYPE, GSet2}) ->
    ordsets_ext:equal(GSet1, GSet2).

%% @doc Check if a GSet is bottom.
-spec is_bottom(delta_or_state()) -> boolean().
is_bottom({?TYPE, {delta, GSet}}) ->
    is_bottom({?TYPE, GSet});
is_bottom({?TYPE, GSet}) ->
    ordsets:size(GSet) == 0.

%% @doc Given two `state_gset()', check if the second is an inflation
%%      of the first.
%%      The second `state_gset()' is an inflation if the first set is
%%      a subset of the second.
-spec is_inflation(delta_or_state(), state_gset()) -> boolean().
is_inflation({?TYPE, {delta, GSet1}}, {?TYPE, GSet2}) ->
    is_inflation({?TYPE, GSet1}, {?TYPE, GSet2});
is_inflation({?TYPE, GSet1}, {?TYPE, GSet2}) ->
    ordsets:is_subset(GSet1, GSet2).

%% @doc Check for strict inflation.
-spec is_strict_inflation(delta_or_state(), state_gset()) -> boolean().
is_strict_inflation({?TYPE, {delta, GSet1}}, {?TYPE, GSet2}) ->
    is_strict_inflation({?TYPE, GSet1}, {?TYPE, GSet2});
is_strict_inflation({?TYPE, _}=CRDT1, {?TYPE, _}=CRDT2) ->
    state_type:is_strict_inflation(CRDT1, CRDT2).

%% @doc Join decomposition for `state_gset()'.
%%      The join decompostion for a `state_gset()' is the unique set
%%      partition where each set of the partition has exactly one
%%      element.
-spec join_decomposition(state_gset()) -> [state_gset()].
join_decomposition({?TYPE, GSet}) ->
    ordsets:fold(
        fun(Elem, Acc) ->
            [{?TYPE, [Elem]} | Acc]
        end,
        [],
        GSet
    ).

%% ===================================================================
%% EUnit tests
%% ===================================================================
-ifdef(TEST).

new_test() ->
    ?assertEqual({?TYPE, ordsets:new()}, new()).

query_test() ->
    Set0 = new(),
    Set1 = {?TYPE, [<<"a">>]},
    ?assertEqual(sets:new(), query(Set0)),
    ?assertEqual(sets:from_list([<<"a">>]), query(Set1)).

delta_add_test() ->
    Actor = 1,
    Set0 = new(),
    {ok, {?TYPE, {delta, Delta1}}} = delta_mutate({add, <<"a">>}, Actor, Set0),
    Set1 = merge({?TYPE, Delta1}, Set0),
    {ok, {?TYPE, {delta, Delta2}}} = delta_mutate({add, <<"a">>}, Actor, Set1),
    Set2 = merge({?TYPE, Delta2}, Set1),
    {ok, {?TYPE, {delta, Delta3}}} = delta_mutate({add, <<"b">>}, Actor, Set2),
    Set3 = merge({?TYPE, Delta3}, Set2),
    ?assertEqual({?TYPE, [<<"a">>]}, {?TYPE, Delta1}),
    ?assertEqual({?TYPE, [<<"a">>]}, Set1),
    ?assertEqual({?TYPE, []}, {?TYPE, Delta2}),
    ?assertEqual({?TYPE, [<<"a">>]}, Set2),
    ?assertEqual({?TYPE, [<<"b">>]}, {?TYPE, Delta3}),
    ?assertEqual({?TYPE, [<<"a">>, <<"b">>]}, Set3).

add_test() ->
    Actor = 1,
    Set0 = new(),
    {ok, Set1} = mutate({add, <<"a">>}, Actor, Set0),
    {ok, Set2} = mutate({add, <<"b">>}, Actor, Set1),
    ?assertEqual({?TYPE, [<<"a">>]}, Set1),
    ?assertEqual({?TYPE, [<<"a">>, <<"b">>]}, Set2).

merge_idempontent_test() ->
    Set1 = {?TYPE, [<<"a">>]},
    Set2 = {?TYPE, [<<"a">>, <<"b">>]},
    Set3 = merge(Set1, Set1),
    Set4 = merge(Set2, Set2),
    ?assertEqual({?TYPE, [<<"a">>]}, Set3),
    ?assertEqual({?TYPE, [<<"a">>, <<"b">>]}, Set4).

merge_commutative_test() ->
    Set1 = {?TYPE, [<<"a">>]},
    Set2 = {?TYPE, [<<"a">>, <<"b">>]},
    Set3 = merge(Set1, Set2),
    Set4 = merge(Set2, Set1),
    ?assertEqual({?TYPE, [<<"a">>, <<"b">>]}, Set3),
    ?assertEqual({?TYPE, [<<"a">>, <<"b">>]}, Set4).

merge_deltas_test() ->
    Set1 = {?TYPE, [<<"a">>]},
    Delta1 = {?TYPE, {delta, [<<"a">>, <<"b">>]}},
    Delta2 = {?TYPE, {delta, [<<"c">>]}},
    Set2 = merge(Delta1, Set1),
    Set3 = merge(Set1, Delta1),
    DeltaGroup = merge(Delta1, Delta2),
    ?assertEqual({?TYPE, [<<"a">>, <<"b">>]}, Set2),
    ?assertEqual({?TYPE, [<<"a">>, <<"b">>]}, Set3),
    ?assertEqual({?TYPE, {delta, [<<"a">>, <<"b">>, <<"c">>]}}, DeltaGroup).

equal_test() ->
    Set1 = {?TYPE, [<<"a">>]},
    Set2 = {?TYPE, [<<"a">>, <<"b">>]},
    ?assert(equal(Set1, Set1)),
    ?assertNot(equal(Set1, Set2)).

is_bottom_test() ->
    Set0 = new(),
    Set1 = {?TYPE, [<<"a">>]},
    ?assert(is_bottom(Set0)),
    ?assertNot(is_bottom(Set1)).

is_inflation_test() ->
    Set1 = {?TYPE, [<<"a">>]},
    DeltaSet1 = {?TYPE, {delta, [<<"a">>]}},
    Set2 = {?TYPE, [<<"a">>, <<"b">>]},
    ?assert(is_inflation(Set1, Set1)),
    ?assert(is_inflation(Set1, Set2)),
    ?assert(is_inflation(DeltaSet1, Set1)),
    ?assert(is_inflation(DeltaSet1, Set2)),
    ?assertNot(is_inflation(Set2, Set1)),
    %% check inflation with merge
    ?assert(state_type:is_inflation(Set1, Set1)),
    ?assert(state_type:is_inflation(Set1, Set2)),
    ?assertNot(state_type:is_inflation(Set2, Set1)).

is_strict_inflation_test() ->
    Set1 = {?TYPE, [<<"a">>]},
    DeltaSet1 = {?TYPE, {delta, [<<"a">>]}},
    Set2 = {?TYPE, [<<"a">>, <<"b">>]},
    ?assertNot(is_strict_inflation(Set1, Set1)),
    ?assert(is_strict_inflation(Set1, Set2)),
    ?assertNot(is_strict_inflation(DeltaSet1, Set1)),
    ?assert(is_strict_inflation(DeltaSet1, Set2)),
    ?assertNot(is_strict_inflation(Set2, Set1)).

join_decomposition_test() ->
    Set1 = {?TYPE, [<<"a">>]},
    Set2 = {?TYPE, [<<"a">>, <<"b">>]},
    Decomp1 = join_decomposition(Set1),
    Decomp2 = join_decomposition(Set2),
    ?assertEqual([{?TYPE, [<<"a">>]}], Decomp1),
    ?assertEqual(lists:sort([{?TYPE, [<<"a">>]}, {?TYPE, [<<"b">>]}]), lists:sort(Decomp2)).

-endif.
