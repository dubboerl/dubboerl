%%------------------------------------------------------------------------------
%% Licensed to the Apache Software Foundation (ASF) under one or more
%% contributor license agreements.  See the NOTICE file distributed with
%% this work for additional information regarding copyright ownership.
%% The ASF licenses this file to You under the Apache License, Version 2.0
%% (the "License"); you may not use this file except in compliance with
%% the License.  You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%------------------------------------------------------------------------------
-module(dubbo_invoker).

-include("dubbo.hrl").
%% API
-export([]).


%% API
-export([invoke_request/2, invoke_request/3, invoke_request/5, invoke_response/2]).

-spec invoke_request(Interface :: binary(), Request :: #dubbo_request{}) ->
    {ok, reference()}|
    {ok, reference(), Data :: any(), RpcContent :: list()}|
    {error, Reason :: timeout|no_provider|any()}.
invoke_request(Interface, Request) ->
    invoke_request(Interface, Request, [], #{}, self()).

-spec invoke_request(Interface :: binary(), Request :: #dubbo_request{}, RequestOption :: map()) ->
    {ok, reference()}|
    {ok, reference(), Data :: any(), RpcContent :: list()}|
    {error, Reason :: timeout|no_provider|any()}.
invoke_request(Interface, Request, RequestOption) ->
    invoke_request(Interface, Request, RequestOption, self()).


-spec invoke_request(Interface :: binary(), Request :: #dubbo_request{}, RpcContext :: list(), RequestState :: map(), CallBackPid :: pid()) ->
    {ok, reference()}|
    {ok, reference(), Data :: any(), RpcContent :: list()}|
    {error, Reason :: timeout|no_provider|request_full|any()}.
invoke_request(Interface, Request, _RpcContext, _RequestState, CallBackPid) ->
    invoke_request(Interface,Request,#{},CallBackPid).

invoke_request(Interface, Request, RequestOption, CallBackPid) ->
    case dubbo_provider_consumer_reg_table:get_interface_info(Interface) of
        undefined ->
            {error, no_provider};
        #interface_info{protocol = Protocol, loadbalance = LoadBalance} ->
            ReferenceConfig = #reference_config{sync = is_sync(RequestOption)},
            Ref = get_ref(RequestOption),
            RpcContext = get_ctx(RequestOption),
            Attachments = merge_attachments(Request,RpcContext),
            Invocation = Request#dubbo_request.data#dubbo_rpc_invocation{
                loadbalance = LoadBalance,
                call_ref = Ref,
                reference_ops = ReferenceConfig,
                source_pid = CallBackPid,
                attachments = Attachments
            },
            Result = dubbo_extension:invoke(filter, invoke, [Invocation], {ok, Ref}, [Protocol]),
            Result
    end.

invoke_response(Invocation, Result) ->
    Result2 = dubbo_extension:invoke_foldr(filter, on_response, [Invocation], Result),
    gen_server:cast(Invocation#dubbo_rpc_invocation.source_pid, {response_process, Invocation#dubbo_rpc_invocation.call_ref, Invocation#dubbo_rpc_invocation.attachments, Result2}),
    ok.

is_sync(Option) ->
    maps:is_key(sync, Option).
get_ref(Option) ->
    maps:get(ref, Option, make_ref()).
get_ctx(Option)->
    maps:get(ctx, Option, []).

merge_attachments(Request, OptionAttachments) ->
    Attachments = Request#dubbo_request.data#dubbo_rpc_invocation.attachments,
    List = [
        {<<"version">>, <<"0.0.0">>}
    ],
    lists:merge3(Attachments, OptionAttachments, List).
