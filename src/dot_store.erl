%%
%% Copyright (c) 2015-2016 Christopher Meiklejohn.  All Rights Reserved.
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

%% @doc DotStores:
%%       - DotSet
%%       - DotFun
%%       - DotMap
%%
%% @reference Paulo Sérgio Almeida, Ali Shoker, and Carlos Baquero
%%      Delta State Replicated Data Types (2016)
%%      [http://arxiv.org/pdf/1603.01529v1.pdf]

-module(dot_store).
-author("Vitor Enes Duarte <vitorenesduarte@gmail.com>").

-export_type([dot_actor/0,
              dot/0,
              dot_store/0,
              dot_set/0,
              dot_fun/0,
              dot_map/0,
              type/0]).

-type dot_actor() :: term().
-type dot() :: {dot_actor(), pos_integer()}.

-type dot_set_payload() :: ordsets:ordset(dot()).
-type dot_set() :: {dot_set, dot_set_payload()}.

-type dot_fun_payload() :: orddict:orddict(dot(), term()).
-type dot_fun() :: {{dot_fun, state_type:state_type()}, dot_fun_payload()}.

-type dot_map_payload() :: orddict:orddict(term(), dot_store()).
-type dot_map() :: {{dot_map, type()}, dot_map_payload()}.

-type type() :: dot_set |
                {dot_fun, state_type:state_type()} |
                {dot_map, type()} |
                state_type:state_type().
-type dot_store() :: dot_set() | dot_fun() | dot_map().


%% @doc Create an empty DotStore.
-callback new() -> dot_store().
-callback new(term()) -> dot_store().

%% @doc Check if a DotStore is empty.
-callback is_empty(dot_store()) -> boolean().
