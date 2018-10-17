%%%-------------------------------------------------------------------
%%% @author dlive
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 20. 十月 2016 下午5:55
%%%-------------------------------------------------------------------
-module(de_heartbeat).
-author("dlive").

-include("dubbo.hrl").
%% API
-export([generate_request/2]).
generate_request(undefined,NeedResponse)->
    RequestId = de_id_count:gen_id(),
    generate_request(RequestId,NeedResponse);
generate_request(RequestId,NeedResponse)->
    Req = #dubbo_request{is_event = true,is_twoway = true,mid = RequestId,data = undefined,mversion= <<"2.0.0">>},
    {ok,Bin} = de_codec:encode_request(Req),
    {ok,Bin}.