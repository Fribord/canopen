%%%---- BEGIN COPYRIGHT --------------------------------------------------------
%%%
%%% Copyright (C) 2007 - 2012, Rogvall Invest AB, <tony@rogvall.se>
%%%
%%% This software is licensed as described in the file COPYRIGHT, which
%%% you should have received as part of this distribution. The terms
%%% are also available at http://www.rogvall.se/docs/copyright.txt.
%%%
%%% You may opt to use, copy, modify, merge, publish, distribute and/or sell
%%% copies of the Software, and permit persons to whom the Software is
%%% furnished to do so, under the terms of the COPYRIGHT file.
%%%
%%% This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
%%% KIND, either express or implied.
%%%
%%%---- END COPYRIGHT ----------------------------------------------------------
%%%-------------------------------------------------------------------
%%% @author Tony Rogvall <tony@rogvall.se>
%%% @author Malotte W L�nne <malotte@malotte.net>
%%% @copyright (C) 2012, Tony Rogvall
%%% @doc
%%%    CANopen SDO Server Finite State Machine
%%%
%%%    Started by the CANOpen node when an SDO session is initialized.
%%%
%%% State diagrams: Download segment <br/>
%%%
%%% <a href="../doc/co_sdo_srv_segment_download_state_diagram1.jpg"> 
%%% Download segment1 - s_initial</a><br/>
%%% <a href="../doc/co_sdo_srv_segment_download_state_diagram2.jpg"> 
%%% Download segment2 - s_writing_segment_started</a><br/>
%%% <a href="../doc/co_sdo_srv_segment_download_state_diagram3.jpg"> 
%%% Download segment3 - s_segmented_download</a><br/>
%%% <a href="../doc/co_sdo_srv_segment_download_state_diagram4.jpg"> 
%%% Download segment4 - s_writing_segment_end</a><br/>
%%% 
%%% State diagrams: Upload segment <br/>
%%%
%%% <a href="../doc/co_sdo_srv_segment_upload_state_diagram1.jpg"> 
%%% Upload segment1 - s_initial</a><br/>
%%% <a href="../doc/co_sdo_srv_segment_upload_state_diagram2.jpg"> 
%%% Upload segment2 - s_reading_segment_started</a><br/>
%%% <a href="../doc/co_sdo_srv_segment_upload_state_diagram3.jpg"> 
%%% Upload segment3 - s_segmented_upload</a><br/>
%%% <a href="../doc/co_sdo_srv_segment_upload_state_diagram4.jpg"> 
%%% Upload segment4 - s_reading_segment</a><br/>
%%% 
%%% State diagrams: Download block <br/>
%%%
%%% <a href="../doc/co_sdo_srv_block_download_state_diagram1.jpg"> 
%%% Download block1 - s_initial</a><br/>
%%% <a href="../doc/co_sdo_srv_block_download_state_diagram2.jpg"> 
%%% Download block2 - s_writing_block_started</a><br/>
%%% <a href="../doc/co_sdo_srv_block_download_state_diagram3.jpg"> 
%%% Download block3 - s_blocked_download</a><br/>
%%% <a href="../doc/co_sdo_srv_block_download_state_diagram4.jpg"> 
%%% Download block4 - s_block_download_end</a><br/>
%%% <a href="../doc/co_sdo_srv_block_download_state_diagram5.jpg"> 
%%% Download block5 - s_writing_block_end</a><br/>
%%% 
%%% State diagrams: Upload block <br/>
%%%
%%% <a href="../doc/co_sdo_srv_block_upload_state_diagram1.jpg"> 
%%% Upload block1 - s_initial</a><br/>
%%% <a href="../doc/co_sdo_srv_block_upload_state_diagram2.jpg"> 
%%% Upload block2 - s_reading_block_started</a><br/>
%%% <a href="../doc/co_sdo_srv_block_upload_state_diagram3.jpg"> 
%%% Upload block3 - s_block_upload_start</a><br/>
%%% <a href="../doc/co_sdo_srv_block_upload_state_diagram4.jpg"> 
%%% Upload block4 - s_reading_block_segment</a><br/>
%%% <a href="../doc/co_sdo_srv_block_upload_state_diagram5.jpg"> 
%%% Upload block5 - s_block_upload_response</a><br/>
%%% <a href="../doc/co_sdo_srv_block_upload_state_diagram6.jpg"> 
%%% Upload block6 - s_block_upload_response_last</a><br/>
%%% <a href="../doc/co_sdo_srv_block_upload_state_diagram7.jpg"> 
%%% Upload block7 - s_block_pload_end_response</a><br/>
%%% 
%%% File: co_sdo_srv_fsm.erl<br/>
%%% Created:  2 Jun 2010 by Tony Rogvall
%%% @end
%%%-------------------------------------------------------------------
-module(co_sdo_srv_fsm).

-behaviour(gen_fsm).

-include_lib("can/include/can.hrl").
-include("canopen.hrl").
-include("sdo.hrl").
-include("co_app.hrl").
-include("co_debug.hrl").

%% API
-export([start/3]).

%% gen_fsm callbacks
-export([init/1, handle_event/3,
	 handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).

%% Start state for all
-export([s_initial/2]).

%% Segment download
-export([s_segmented_download/2]).
-export([s_writing_segment_started/2]). %% Streamed
-export([s_writing_segment_end/2]).     %% Streamed

%% Segment upload
-export([s_segmented_upload/2]).
-export([s_reading_segment_started/2]). %% Streamed
-export([s_reading_segment/2]).         %% Streamed

%% Block upload
-export([s_block_upload_start/2]).
-export([s_block_upload_response/2]).
-export([s_block_upload_response_last/2]).
-export([s_block_upload_end_response/2]).
-export([s_reading_block_started/2]).   %% Streamed
-export([s_reading_block_segment/2]).   %% Streamed

%% Block download
-export([s_block_download/2]).
-export([s_block_download_end/2]).
-export([s_writing_block_started/2]).   %% Streamed
-export([s_writing_block_end/2]).       %% Streamed

		 
%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @spec start(Ctx, Src, Dst) -> {ok, Pid} | ignore | {error, Error}
%%
%% @doc
%% Starts the session state machine.
%%
%% @end
%%--------------------------------------------------------------------
start(Ctx,Src,Dst) when is_record(Ctx, sdo_ctx) ->
    gen_fsm:start(?MODULE, {Ctx,self(),Src,Dst}, []).

%%%===================================================================
%%% gen_fsm callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @spec init(Args) -> {ok, StateName, State} |
%%                     {ok, StateName, State, Timeout} |
%%                     ignore |
%%                     {stop, StopReason}
%% @doc
%% Whenever a gen_fsm is started using gen_fsm:start/[3,4] or
%% gen_fsm:start_link/[3,4], this function is called by the new
%% process to initialize.
%%
%% @end
%%--------------------------------------------------------------------
init({Ctx,NodePid,Src,Dst}) when is_record(Ctx, sdo_ctx) ->
    put(dbg, Ctx#sdo_ctx.debug),
    ?dbg(srv,"init: src=~p, dst=~p \n", [Src, Dst]),
    S0 = #co_session {
      src    = Src,
      dst    = Dst,
      index  = undefined,
      subind = undefined,
      exp    = 0,
      size_ind = 0,
      pst    = 0,
      t      = 0,         %% Toggle value
      clientcrc = false,
      crc    = false,     %% Check or Generate CRC
      blksize  = 0,
      blkseq   = 0,
      blkbytes = 0,
      node_pid = NodePid,
      ctx      = Ctx,
      buf = undefined,
      mref = undefined
      %% transfer is setup when we know the item
     },
    {ok, s_initial, S0, timeout(S0)}.

%%--------------------------------------------------------------------
%% @doc
%% Initial state.<br/>
%% Expected events are:
%% <ul>
%% <li>initiate_download_request</li>
%% <li>block_download_request</li>
%% <li>initiate_upload_request</li>
%% <li>block_upload_request</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_writing_segment_started </li>
%% <li> s_writing_block_started </li>
%% <li> s_reading_segment_started </li>
%% <li> s_reading_block_started </li>
%% <li> s_writing_segment_end </li>
%% <li> s_segment_download </li>
%% <li> s_segmented_upload </li>
%% <li> s_block_download </li>
%% <li> s_block_upload_start </li>
%% <li> stop </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_initial(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_initial(M, S) when is_record(M, can_frame) ->
    case M#can_frame.data of
	?ma_ccs_initiate_download_request(N,Expedited,SizeInd,Ix,Si,Data) ->
	    S1 = S#co_session{index=Ix, subind=Si, exp=Expedited, 
			      data=Data, size_ind=SizeInd, n=N},
	    case write_begin(S1) of
		{ok, Buf}  ->
		    %% FIXME: check if max_size already set, reject if bad
		    start_segment_download(S1#co_session {buf = Buf});
		{ok, Buf, Mref} when is_reference(Mref) ->
		    %% Application called, wait for reply
		    ?dbg(srv, "s_initial: mref=~p\n", [Mref]),
		    S2 = S1#co_session { buf=Buf, mref=Mref },
		    {next_state, s_writing_segment_started,S2,timeout(S2)};
		{error, Reason} ->
		    ?dbg(srv, "s_initial: write failed, reason = ~p", [Reason]),
		    abort(S1, Reason)
	    end;

	?ma_ccs_block_download_request(ChkCrc,SizeInd,Ix,Si,Size) ->
	    S1 = S#co_session { index=Ix, subind=Si, 
				size_ind=SizeInd, size=Size,
				crc=(ChkCrc =:= 1)},
	    case write_begin(S1) of
		{ok, Buf}  -> 
		    %% FIXME: check if max_size already set, reject if bad
		    start_block_download(S1#co_session {buf = Buf});
		{ok, Buf, Mref} ->
		    %% Application called, wait for reply
		    ?dbg(srv, "s_initial: mref=~p\n", [Mref]),
		    S2 = S1#co_session { buf=Buf, mref=Mref },
		    {next_state, s_writing_block_started,S2,timeout(S2)};
		{error,Reason} ->
		    ?dbg(srv, "s_initial: write failed, reason = ~p", [Reason]),
		    abort(S1, Reason)
	    end;

	?ma_ccs_initiate_upload_request(Ix,Si) ->
	    S1 = S#co_session {index=Ix,subind=Si},
	    case read_begin(S1) of
		{ok, Buf} ->
		    start_segmented_upload(S1#co_session {buf = Buf});
		{ok, Buf, Mref} when is_reference(Mref) ->
		    %% Application called, wait for reply
		    ?dbg(srv, "s_initial: mref=~p\n", [Mref]),
		    S2 = S1#co_session {mref = Mref, buf = Buf},
		    {next_state, s_reading_segment_started, S2, timeout(S2)};
		{error,Reason} ->
		    ?dbg(srv, "s_initial: read failed, reason = ~p", [Reason]),
		    abort(S1, Reason)
	    end;

	?ma_ccs_block_upload_request(GenCrc,Ix,Si,BlkSize,Pst) ->
	    ?dbg(srv, "s_initial: block_upload_request blksize = ~p\n",
		 [BlkSize]),
	    S1 = S#co_session {index=Ix, subind=Si, pst=Pst, blksize=BlkSize, 
			       clientcrc=(GenCrc =:= 1)},
	    case read_begin(S1) of
		{ok, Buf} ->
		    NBytes = co_data_buf:data_size(Buf),
		    if Pst =/= 0, NBytes > 0, NBytes =< Pst ->
			    ?dbg(srv, "protocol switch\n",[]),
			    start_segmented_upload(S1#co_session {buf = Buf});
		       true ->
			    start_block_upload(S1#co_session {buf = Buf})
		       end;
		{ok, Buf, Mref} when is_reference(Mref) ->
		    %% Application called, wait for reply
		    ?dbg(srv, "s_initial: mref=~p\n", [Mref]),
		    S2 = S1#co_session {mref = Mref, buf = Buf},
		    {next_state, s_reading_block_started, S2, timeout(S2)};
		{error,Reason} ->
		    ?dbg(srv,"s_initial: read failed, reason = ~p\n", [Reason]),
		    abort(S1, Reason)
	    end;
	?ma_ccs_abort_transfer(Ix,Si,Code) ->
	    ?dbg(srv, "s_initial: abort_transfer, index = ~7.16.0#:~w, code = ~p\n",
		 [Ix, Si, Code]),
	    %% If needed add:
	    %% co_api:session_over(S#co_session.node_pid, 
            %%                     {abort, {Ix, Si}, Code}),
	    {stop, normal, S};	    
	_ ->
	    l_abort(M, S, s_initial)
    end;
s_initial(timeout, S) ->
    {stop, timeout, S}.

%%--------------------------------------------------------------------
%% @doc 
%% Start a write operation.
%% @end
%%--------------------------------------------------------------------
-spec write_begin(S::#co_session{}) ->
			{ok, Mref::reference(), Buf::term()} | 
			{ok, Buf::term()} |
			{error, Error::atom()}.

write_begin(_S=#co_session {ctx = Ctx, index = Index, subind = SubInd, node_pid = NodePid}) ->
    case co_api:reserver_with_module(Ctx#sdo_ctx.res_table, Index) of
	[] ->
	    ?dbg(srv, "write_begin: No reserver for index ~7.16.0#\n", [Index]),
	    central_write_begin(Ctx, Index, SubInd);
	{NodePid, _Mod} when is_pid(NodePid) ->
	    ?dbg(srv, "write_begin: co_node ~p has reserved index ~7.16.0#\n", 
		 [NodePid, Index]),
	    central_write_begin(Ctx, Index, SubInd);
	{Pid, Mod} when is_pid(Pid) ->
	    ?dbg(srv, "write_begin: Process ~p, ~p has reserved index ~7.16.0#\n", 
		 [Pid, Mod, Index]),
	    app_write_begin(Index, SubInd, Pid, Mod);
	{dead, _Mod} ->
	    ?dbg(srv, "write_begin: Reserver process for index ~7.16.0# dead.\n", [Index]),
	    {error, ?abort_internal_error}
    end.


central_write_begin(_Ctx=#sdo_ctx {dict = Dict}, Index, SubInd) ->
    case co_dict:lookup_entry(Dict, {Index,SubInd}) of
	{ok,E} ->
	    if (E#dict_entry.access band ?ACCESS_WO) =:= ?ACCESS_WO ->
		    ?dbg(srv, "central_write_begin: Write access ok\n", []),
		    co_data_buf:init(write, Dict, E);
	       true ->
		    {error,?abort_write_not_allowed}
	    end;
	{error, Reason}  ->
	    {error, Reason}
    end.

app_write_begin(Index, SubInd, Pid, Mod) ->
    case Mod:index_specification(Pid, {Index, SubInd}) of
	{spec, Spec} ->
	    if (Spec#index_spec.access band ?ACCESS_WO) =:= ?ACCESS_WO ->
		    ?dbg(srv, "app_write_begin: transfer=~p, type = ~p\n",
			 [Spec#index_spec.transfer, Spec#index_spec.type]),
		    co_data_buf:init(write, Pid, Spec);
	       true ->
		    {error, ?abort_unsupported_access}
	    end;
	{error, Reason}  ->
	    {error, Reason}
    end.
    

%%--------------------------------------------------------------------
%% @doc 
%% Start a read operation.
%% @end
%%--------------------------------------------------------------------
-spec read_begin(S::#co_session{}) ->
			{ok, Mref::reference(), Buf::term()} | 
			{ok, Buf::term()} |
			{error, Error::atom()}.

read_begin(_S=#co_session {ctx = Ctx, index = Index, subind = SubInd}) ->
    case co_api:reserver_with_module(Ctx#sdo_ctx.res_table, Index) of
	[] ->
	    ?dbg(srv, "read_begin: No reserver for index ~7.16.0#\n", [Index]),
	    central_read_begin(Ctx, Index, SubInd);
	{Pid, Mod} when is_pid(Pid)->
	    ?dbg(srv, "read_begin: Process ~p subscribes to index ~7.16.0#\n", 
		 [Pid, Index]),
	    app_read_begin(Ctx, Index, SubInd, Pid, Mod);
	{dead, _Mod} ->
	    ?dbg(srv, "read_begin: Reserver process for index ~7.16.0# dead.\n", [Index]),
	    {error, ?abort_internal_error}
    end.

central_read_begin(Ctx, Index, SubInd) ->
    Dict = Ctx#sdo_ctx.dict,
    case co_dict:lookup_entry(Dict, {Index,SubInd}) of
	{ok,E} ->
	    if (E#dict_entry.access band ?ACCESS_RO) =:= ?ACCESS_RO ->
		    ?dbg(srv, "central_read_begin: Read access ok\n", []),
		    co_data_buf:init(read, Dict, E,
				     Ctx#sdo_ctx.readbufsize, 
				     trunc(Ctx#sdo_ctx.readbufsize * 
					       Ctx#sdo_ctx.load_ratio));
	       true ->
		    {error, ?abort_read_not_allowed}
	    end;
	{error, Reason}  ->
	    {error, Reason}
    end.

app_read_begin(Ctx, Index, SubInd, Pid, Mod) ->
    case Mod:index_specification(Pid, {Index, SubInd}) of
	{spec, Spec} ->
	    if (Spec#index_spec.access band ?ACCESS_RO) =:= ?ACCESS_RO ->
		    ?dbg(srv, "app_read_begin: Read access ok\n", []),
		    ?dbg(srv, "app_read_begin: Transfer mode = ~p\n", 
			 [Spec#index_spec.transfer]),
		    co_data_buf:init(read, Pid, Spec, 
				     Ctx#sdo_ctx.readbufsize, 
				     trunc(Ctx#sdo_ctx.readbufsize * 
					       Ctx#sdo_ctx.load_ratio));
	       true ->
		    {error, ?abort_read_not_allowed}
	    end;
	Error ->
	    Error
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%% SEGMENT DOWNLOAD
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%--------------------------------------------------------------------
%% @doc 
%% Start downloading segments.
%% @end
%%--------------------------------------------------------------------
start_segment_download(S=#co_session {index = Ix, subind = Si}) ->
    if S#co_session.exp =:= 1 ->
	    %% Only one segment to write
	    NBytes = if S#co_session.size_ind =:= 1 -> 4-S#co_session.n;
			true -> 0
		     end,
	    <<Data:NBytes/binary, _Filler/binary>> = S#co_session.data,
	    ?dbg(srv, "start_segment_download: expedited, Data = ~p\n", [Data]),
	    case co_data_buf:write(S#co_session.buf, Data, true, segment) of
		{ok, Buf1, Mref} when is_reference(Mref) ->
		    %% Called an application
		    ?dbg(srv, "start_segmented_download: mref=~p\n", [Mref]),
		    S1 = S#co_session {mref = Mref, buf = Buf1},
		    {next_state, s_writing_segment_end, S1, timeout(S1)};
		{ok, _Buf1} ->
		    co_api:object_event(S#co_session.node_pid, {Ix, Si}),
		    co_api:session_over(S#co_session.node_pid, normal),
		    R = ?mk_scs_initiate_download_response(Ix,Si),
		    send(S, R),
		    {stop, normal, S};
		{error,Reason} ->
		    ?dbg(srv, "start_segment_download: write failed, reason = ~p", [Reason]),
		    abort(S, Reason)
	    end;
       true ->
	    ?dbg(srv, "start_segment_download: not expedited\n", []),
	    %% FIXME: check if max_size already set
	    %% reject if bad!
	    %% set T=1 since client will start wibuf 0
	    S1 = S#co_session {t=1},
	    R  = ?mk_scs_initiate_download_response(Ix,Si),
	    send(S1, R),
	    {next_state, s_segmented_download, S1, timeout(S1)}
    end.

 
%%--------------------------------------------------------------------
%% @doc
%% Sending segments.<br/>
%% Expected events are:
%% <ul>
%% <li>download_segment_request</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_reading_segment </li>
%% <li> s_segment_download </li>
%% <li> s_segment_download_end</li>
%% <li> stop </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_segmented_download(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_segmented_download(M, 
		     S=#co_session {index = Ix, subind = Si, node_pid = NPid}) 
  when is_record(M, can_frame) ->
    case M#can_frame.data of
	?ma_ccs_download_segment_request(T,_N,_C,_D) 
	  when T =:= S#co_session.t ->
	    abort(S, ?abort_toggle_not_alternated);

	?ma_ccs_download_segment_request(T,N,Last,Data) ->
	    NBytes = 7-N,
	    Eod = (Last =:= 1),
	    <<DataToWrite:NBytes/binary, _Filler/binary>> = Data,
	    case co_data_buf:write(S#co_session.buf, DataToWrite, Eod, segment) of
		{ok, Buf, Mref} ->
		    %% Called an application
		    ?dbg(srv, "s_segmented_download: mref=~p\n", [Mref]),
		    S1 = S#co_session {t = T, mref = Mref, buf = Buf},
		    if Eod ->
			    %% Wait for write reply from app
			    {next_state, s_writing_segment_end, S1,timeout(S1)};
		       true ->
			    %% Reply with same toggle value as the request
			    R = ?mk_scs_download_segment_response(T),
			    send(S1,R),
			    {next_state, s_segmented_download, S1,timeout(S1)}
		    end;
		{ok, Buf} ->
		    if Eod ->
			    %% Tell node object has been changed and 
			    %% that we are finished and don't want more
			    %% frames.
			    co_api:object_event(NPid, {Ix, Si}),
			    co_api:session_over(NPid, normal);
		       true ->
			    tell_no_one
		    end,
		    %% Reply with same toggle value as the request
		    S1 = S#co_session {t = T, buf = Buf},
		    R = ?mk_scs_download_segment_response(T),
		    send(S1,R),
		    if Eod ->
			    {stop, normal, S1};
		       true ->
			    {next_state, s_segmented_download, S1,timeout(S1)}
		    end;
		{error,Reason} ->
		    ?dbg(srv, "s_segmented_download: write failed, reason = ~p", [Reason]),
		    abort(S,Reason)
	    end;
	_ ->
	    l_abort(M, S, s_segmented_download)
    end;
s_segmented_download(timeout, S) ->
    abort(S, ?abort_timed_out).

%%--------------------------------------------------------------------
%% @doc
%% Initializing write for application stored data.<br/>
%% Expected events are:
%% <ul>
%% <li>{Mref, {ok, Ref, Size}}</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_writing_segment_end </li>
%% <li> s_segment_download </li>
%% <li> stop </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_writing_segment_started(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_writing_segment_started({Mref, Reply} = _M, S)  ->
    ?dbg(srv, "s_writing_segment_started: Got event = ~p\n", [_M]),
    case S#co_session.mref of
	Mref ->
	    erlang:demonitor(Mref, [flush]),
	    {ok, Buf} = co_data_buf:update(S#co_session.buf, Reply),
	    start_segment_download(S#co_session {buf = Buf});
	_Other ->
	    ?dbg(srv, "s_writing_segment_started: received = ~p, aborting", [_Other]),
	    abort(S, ?abort_internal_error)
    end;
s_writing_segment_started(timeout, S) ->
    abort(S, ?abort_timed_out);
s_writing_segment_started(M, S)  ->
    ?dbg(srv, "s_writing_segment_started: Got event = ~p, aborting\n", [M]),
    demonitor_and_abort(M, S).


%%--------------------------------------------------------------------
%% @doc
%% Writing to application. <br/>
%% Expected events are:
%% <ul>
%% <li>{Mref, ok}</li>
%% <li>{Mref, {ok, Ref}}</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> stop </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_writing_segment_end(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_writing_segment_end({Mref, Reply} = _M, 
		      S=#co_session {index = Index, subind = SubInd, t = T})  ->
    ?dbg(srv, "s_writing_segment_end: Got event = ~p\n", [_M]),
    Ok = case {S#co_session.mref, Reply} of
	     {Mref, ok} ->
		 %% Atomic reply
		 ok;
	     {Mref, {ok, Ref}} when is_reference(Ref)->
		 %% Streamed reply
		 ok;
	     _Other ->
		 not_ok
	 end,
    case Ok of
	ok ->
	    erlang:demonitor(Mref, [flush]),
	    co_api:object_event(S#co_session.node_pid, {Index, SubInd}),
	    co_api:session_over(S#co_session.node_pid, normal),
	    if S#co_session.exp =:= 1 ->
		    ?dbg(srv, "s_writing_segment_end: expedited\n", []),
		    %% No response has been sent
		    R = ?mk_scs_initiate_download_response(Index, SubInd),
		    send(S,R);
	       true ->
		    ?dbg(srv, "s_writing_segment_end: not expedited\n", []),
		    %% Last reply with same toggle value as the request
		    R = ?mk_scs_download_segment_response(T),
		    send(S,R)
	    end,
	    {stop, normal, S};
	not_ok ->
	    ?dbg(srv, "s_writing_segment_end: received other = ~p, aborting", [_M]),
	    abort(S, ?abort_internal_error)
     end;
s_writing_segment_end(timeout, S) ->
    abort(S, ?abort_timed_out);
s_writing_segment_end(M, S)  ->
    ?dbg(srv, "s_writing_segment_end: Got event = ~p, aborting\n", [M]),
    demonitor_and_abort(M, S).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%% SEGMENT UPLOAD
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%--------------------------------------------------------------------
%% @doc 
%% Start uploading segments.
%% @end
%%--------------------------------------------------------------------
start_segmented_upload(S=#co_session {index = Ix, subind = Si, buf = Buf}) ->
    ?dbg(srv, "start_segmented_upload\n", []),
    NBytes = co_data_buf:data_size(Buf),
    EofFlag = co_data_buf:eof(Buf),
    ?dbg(srv, "start_segmented_upload, nbytes = ~p, eof = ~p\n", 
	 [NBytes, EofFlag]),
    if NBytes =/= 0, NBytes =< 4 andalso EofFlag =:= true ->
	    case co_data_buf:read(Buf, NBytes) of
		{ok, Data, true, _Buf1} ->
		    ?dbg(srv, "start_segmented_upload, expedited, data = ~p", 
			 [Data]),
		    co_api:session_over(S#co_session.node_pid, normal),
		    Data1 = co_sdo:pad(Data, 4),
		    E=1,
		    SizeInd=1,
		    N = 4 - NBytes,
		    R=?mk_scs_initiate_upload_response(N,E,SizeInd,Ix,Si,Data1),
		    send(S, R),
		    {stop, normal, S};
		{error, Reason} ->
		    ?dbg(srv, "start_segmented_upload: read failed, reason = ~p", [Reason]),
		    abort(S, Reason)
	    end;
       (NBytes =:= 0 andalso EofFlag =:= true) orelse
       (NBytes =:= undefined) ->
	    ?dbg(srv, "start_segmented_upload, sizeind = 0, size = ~p",[NBytes]),
	    N=0, E=0, SizeInd=0,
	    Data = <<0:32/?SDO_ENDIAN>>, %% filler
	    R=?mk_scs_initiate_upload_response(N,E,SizeInd,
					       Ix,Si,Data),
	    send(S, R),
	    {next_state, s_segmented_upload, S, timeout(S)};
       true ->
	    ?dbg(srv, "start_segmented_upload, sizeind = 1, size = ~p",[NBytes]),
	    N=0, E=0, SizeInd=1,
	    Data = <<NBytes:32/?SDO_ENDIAN>>,
	    R=?mk_scs_initiate_upload_response(N,E,SizeInd,
					       Ix,Si,Data),
	    send(S, R),
	    {next_state, s_segmented_upload, S, timeout(S)}
    end.


%%--------------------------------------------------------------------
%% @doc
%% Uploading segments.<br/>
%% Expected events are:
%% <ul>
%% <li>upload_segment_request</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_reading_segment </li>
%% <li> s_segment_upload </li>
%% <li> stop </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_segmented_upload(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_segmented_upload(M, S) when is_record(M, can_frame) ->
    case M#can_frame.data of
	?ma_ccs_upload_segment_request(T) when T =/= S#co_session.t ->
	    abort(S, ?abort_toggle_not_alternated);
	?ma_ccs_upload_segment_request(T) ->
	    read_segment(S#co_session {t = T});
	_ ->
	    l_abort(M, S, s_segmented_upload)
    end;
s_segmented_upload(timeout, S) ->
    abort(S, ?abort_timed_out).

read_segment(S) ->
    case co_data_buf:read(S#co_session.buf,7) of
	{ok, Data, Eod, Buf} ->
	    ?dbg(srv, "read_segment: data=~p, Size = ~p, Eod=~p\n", 
		 [Data, size(Data), Eod]),
	    upload_segment(S#co_session {buf = Buf}, Data, Eod);
	{ok, Buf, Mref} ->
	    %% Called an application
	    ?dbg(srv, "s_segmented_upload: mref=~p\n", [Mref]),
	    S1 = S#co_session {mref = Mref, buf = Buf},
	    {next_state, s_reading_segment, S1, timeout(S1)};
	{error,Reason} ->
	    ?dbg(srv, "read_segment: read failed, reason = ~p", [Reason]),
	    abort(S,Reason)
    end.

upload_segment(S, Data, Eod) ->
    T1 = 1-S#co_session.t,
    N = 7-size(Data),
    %% erlang:display({T1,Remain,N,Data}),
    if Eod =:= true ->
	    co_api:session_over(S#co_session.node_pid, normal),
	    Data1 = co_sdo:pad(Data,7),
	    R = ?mk_scs_upload_segment_response(S#co_session.t,N,1,Data1),
	    send(S,R),
	    {stop,normal,S};
       true ->
	    Data1 = co_sdo:pad(Data,7),
	    R = ?mk_scs_upload_segment_response(S#co_session.t,N,0,Data1),
	    send(S,R),
	    S1 = S#co_session {t=T1},
	    {next_state, s_segmented_upload, S1, timeout(S1)}
    end.

%%--------------------------------------------------------------------
%% @doc
%% Initializing reading for application stored data.<br/>
%% Expected events are:
%% <ul>
%% <li>{Mref, {ok, Value}}</li>
%% <li>{Mref, {ok, Ref, Size}}</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_segment_upload </li>
%% <li> stop </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_reading_segment_started(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_reading_segment_started({Mref, Reply} = _M, S)  ->
    ?dbg(srv, "s_reading_segment_started: Got event = ~p\n", [_M]),
    case {S#co_session.mref, Reply} of
	{Mref, {ok, _Value}} ->
	    %% Atomic
	    erlang:demonitor(Mref, [flush]),
	    {ok, Buf} = co_data_buf:update(S#co_session.buf, Reply),
	    start_segmented_upload(S#co_session {buf = Buf});	    
	{Mref, {ok, _Ref, _Size}} ->
	    %% Streamed
	    erlang:demonitor(Mref, [flush]),
	    {ok, Buf} = co_data_buf:update(S#co_session.buf, Reply),
	    %% Start to fill data buffer
	    case co_data_buf:load(Buf) of
		{ok, Buf1} ->
		    %% Buffer loaded
		    start_segmented_upload(S#co_session {buf = Buf1});
		{ok, Buf1, Mref1} ->
		    %% Wait for data ??
		    ?dbg(srv, "s_reading_segment_started: mref=~p\n", [Mref]),
		    start_segmented_upload(S#co_session {buf = Buf1, mref = Mref1});
		{error, Reason} ->
		    ?dbg(srv, "s_reading_segment_started: load failed, reason = ~p", [Reason]),
		    abort(S, Reason)
	    end;
	_Other ->
	    ?dbg(srv, "s_reading_segment_started: received = ~p, aborting", [_Other]),
	    abort(S, ?abort_internal_error)
     end;
s_reading_segment_started(timeout, S) ->
    abort(S, ?abort_timed_out);
s_reading_segment_started(M, S)  ->
    ?dbg(srv, "s_reading_segment_started: Got event = ~p, aborting\n", [M]),
    demonitor_and_abort(M, S).

%%--------------------------------------------------------------------
%% @doc
%% Reading for application stored data.<br/>
%% Expected events are:
%% <ul>
%% <li>{Mref, {ok, Ref, Data, Eod}}</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_segment_upload </li>
%% <li> s_reading_segment </li>
%% <li> stop </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_reading_segment(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_reading_segment(timeout, S) ->
    abort(S, ?abort_timed_out);
s_reading_segment(M, S) ->
    %% All correct messages should be handled in handle_info()
    ?dbg(srv, "s_reading_segment: Got event = ~p, aborting\n", [M]),
    demonitor_and_abort(M, S).



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%% BLOCK UPLOAD
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%--------------------------------------------------------------------
%% @doc 
%% Start uploading blocks.
%% @end
%%--------------------------------------------------------------------
start_block_upload(S=#co_session {index = Ix, subind = Si, buf = Buf}) ->
    NBytes = case co_data_buf:data_size(Buf) of
		 undefined -> 0;
		 N -> N
	     end,
    ?dbg(srv, "start_block_upload bytes=~p\n", [NBytes]),
    DoCrc = 
	(S#co_session.ctx)#sdo_ctx.use_crc andalso S#co_session.clientcrc,
    CrcSup = ?UINT1(DoCrc),
    R = ?mk_scs_block_upload_response(CrcSup,?UINT1(NBytes > 0),Ix,Si,NBytes),
    S1 = S#co_session { crc=DoCrc, blkcrc=co_crc:init(), blkbytes=0, buf=Buf },
    send(S1, R),
    {next_state, s_block_upload_start,S1,timeout(S1)}.

%%--------------------------------------------------------------------
%% @doc
%% Block upload start.<br/>
%% Expected events are:
%% <ul>
%% <li>block_upload_start</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_block_upload_response </li>
%% <li> s_block_upload_response_last </li>
%% <li> s_reading_block_segment </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_block_upload_start(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_block_upload_start(M, S)  when is_record(M, can_frame) ->
    case M#can_frame.data of
	?ma_ccs_block_upload_start() ->
	    read_block_segment(S#co_session {blkseq = 1});
	_ ->
	    l_abort(M, S, s_block_upload_start)
    end;
s_block_upload_start(timeout, S) ->
    abort(S, ?abort_timed_out).


read_block_segment(S) ->
    ?dbg(srv, "read_block_segment: Seq=~p\n", [S#co_session.blkseq]),
    case co_data_buf:read(S#co_session.buf,7) of
	{ok, Data, Eod, Buf} ->
	    upload_block_segment(S#co_session {buf = Buf}, Data, Eod);
	{ok, Buf, Mref} ->
	    %% Called an application
	    ?dbg(srv, "read_block_segment: mref=~p\n", [Mref]),
	    S1 = S#co_session {mref = Mref, buf = Buf},
	    {next_state, s_reading_block_segment, S1, timeout(S1)};
	{error,Reason} ->
	    ?dbg(srv, "read_block_segment: read failed, reason = ~p", [Reason]),
	    abort(S,Reason)
    end.

upload_block_segment(S, Data, Eod) ->
    ?dbg(srv, "upload_block_segment: Data = ~p, Eod = ~p\n", [Data, Eod]),
    Seq = S#co_session.blkseq,
    Last = ?UINT1(Eod),
    Data1 = co_sdo:pad(Data, 7),
    R = ?mk_block_segment(Last,Seq,Data1),
    NBytes = S#co_session.blkbytes + byte_size(Data),
    ?dbg(srv, "upload_block_segment: data1 = ~p, nbytes = ~p\n",
	 [Data1, NBytes]),
    BlkCrc = if S#co_session.crc ->
		     co_crc:update(S#co_session.blkcrc, Data);
		true ->
		     S#co_session.blkcrc
	     end,
    S1 = S#co_session { blkseq=Seq, blkbytes=NBytes, blkcrc=BlkCrc},
    send(S1, R),
    if Eod ->
	    ?dbg(srv, "upload_block_segment: Last = ~p\n", [Last]),
	    {next_state, s_block_upload_response_last, S1, timeout(S1)};
       Seq =:= S#co_session.blksize ->
	    ?dbg(srv, "upload_block_segment: Seq = ~p\n", [Seq]),
	    {next_state, s_block_upload_response, S1, timeout(S1)};
       true ->
	    read_block_segment(S1#co_session {blkseq = Seq + 1})
    end.

%%--------------------------------------------------------------------
%% @doc
%% Block upload.<br/>
%% Expected events are:
%% <ul>
%% <li>block_upload_response</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_block_upload_response </li>
%% <li> s_block_upload_response_last </li>
%% <li> s_reading_block_segment </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_block_upload_response(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_block_upload_response(M, S) when is_record(M, can_frame) ->
    case M#can_frame.data of
	?ma_ccs_block_upload_response(AckSeq,BlkSize) 
	  when AckSeq == S#co_session.blkseq ->
	    S1 = S#co_session { blkseq=0, blksize=BlkSize },
	    read_block_segment(S1#co_session {blkseq = 1});
	?ma_ccs_block_upload_response(_AckSeq,_BlkSize) ->
	    abort(S, ?abort_invalid_sequence_number);
	_ ->
	    l_abort(M, S, s_block_upload_response)
    end;
s_block_upload_response(timeout,S) ->
    abort(S, ?abort_timed_out).

%%--------------------------------------------------------------------
%% @doc
%% Block upload, last block.<br/>
%% Expected events are:
%% <ul>
%% <li>block_upload_response</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_block_upload_end_response </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_block_upload_response_last(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_block_upload_response_last(M, S) when is_record(M, can_frame) ->
    case M#can_frame.data of
	?ma_ccs_block_upload_response(AckSeq,BlkSize) when AckSeq == S#co_session.blkseq ->
	    S1 = S#co_session { blkseq=0, blksize=BlkSize },
	    TotCrc = co_crc:final(S1#co_session.blkcrc),
	    N = if S1#co_session.blkbytes =:= 0 ->
			%% Special case when sending 0 bytes in total
			7;
		   true ->
			(7- (S1#co_session.blkbytes rem 7)) rem 7
		end,
	    R = ?mk_scs_block_upload_end_request(N,TotCrc),
	    send(S1, R),
	    {next_state, s_block_upload_end_response, S1, timeout(S1)};
	?ma_ccs_block_upload_response(_AckSeq,_BlkSize) ->
	    abort(S, ?abort_invalid_sequence_number);	    
	_ ->
	    l_abort(M, S, s_block_upload_response_last)
    end;
s_block_upload_response_last(timeout,S) ->
    abort(S, ?abort_timed_out).

%%--------------------------------------------------------------------
%% @doc
%% Block upload end.<br/>
%% Expected events are:
%% <ul>
%% <li>block_upload_end_response</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> stop </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_block_upload_end_response(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.
s_block_upload_end_response(M, S) when is_record(M, can_frame) ->
    case M#can_frame.data of
	?ma_ccs_block_upload_end_response() ->
	    {stop, normal, S};
	_ ->
	    l_abort(M, S, s_block_upload_end_response)
    end;
s_block_upload_end_response(timeout, S) ->
    abort(S, ?abort_timed_out).

%%--------------------------------------------------------------------
%% @doc
%% Initilize reading data from application.<br/>
%% Expected events are:
%% <ul>
%% <li>{Mref, {ok, Value}</li>
%% <li>{Mref, {ok, Ref, Size}</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_segmented_upload (protocol switch)</li>
%% <li> s_block_upload_start </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_reading_block_started(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_reading_block_started({Mref, Reply} = _M, S)  ->
    ?dbg(srv, "s_reading_block_started: Got event = ~p\n", [_M]),
    case {S#co_session.mref, Reply} of
	{Mref, {ok, _Value}} ->
	    %% Atomic
	    erlang:demonitor(Mref, [flush]),
	    {ok, Buf} = co_data_buf:update(S#co_session.buf, Reply),
	    segment_or_block(S#co_session {buf = Buf});
	{Mref, {ok, _Ref, _Size}} ->
	    erlang:demonitor(Mref, [flush]),
	    {ok, Buf} = co_data_buf:update(S#co_session.buf, Reply),
	    case co_data_buf:load(Buf) of
		{ok, Buf1} ->
		    %% Buffer loaded
		    start_block_upload(S#co_session {buf = Buf1});
		{ok, Buf1, Mref1} ->
		    ?dbg(srv, "s_reading_block_started: mref=~p\n", [Mref]),
		    start_block_upload(S#co_session {buf = Buf1, mref = Mref1})
	    end;
	_Other ->
	    ?dbg(srv, "s_reading_block_started: received = ~p, aborting", [_Other]),
	    abort(S, ?abort_internal_error)
    end;
s_reading_block_started(timeout, S) ->
    abort(S, ?abort_timed_out);
s_reading_block_started(M, S)  ->
    ?dbg(srv, "s_reading_block_started: Got event = ~p, aborting\n", [M]),
    demonitor_and_abort(M, S).


%% Checks if protocol switch from block to segment should be done
segment_or_block(S) -> 
    NBytes = case co_data_buf:data_size(S#co_session.buf) of
		 undefined -> 0;
		 N -> N
	     end,
    if S#co_session.pst =/= 0, NBytes > 0, 
       NBytes =< S#co_session.pst ->
	    ?dbg(srv, "segment_or_block: protocol switch",[]),
	    start_segmented_upload(S);
       true ->
	    start_block_upload(S)
    end.

%%--------------------------------------------------------------------
%% @doc
%% Reading data from application.<br/>
%% Expected events are:
%% <ul>
%% <li>{Mref, {ok, Ref, Data, Eod}}</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_block_upload_response </li>
%% <li> s_block_upload_response_last </li>
%% <li> s_reading_block_segment </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_reading_block_segment(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.
s_reading_block_segment(timeout, S) ->
    abort(S, ?abort_timed_out);
s_reading_block_segment(M, S) ->
    %% All correct messages should be handled in handle_info()
    ?dbg(srv, "s_reading_segment: Got event = ~p, aborting\n", [M]),
    demonitor_and_abort(M, S).


    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%% BLOCK DOWNLOAD
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%--------------------------------------------------------------------
%% @doc 
%% Start downloading blocks.
%% @end
%%--------------------------------------------------------------------
start_block_download(S=#co_session {index = Ix, subind = Si}) ->
    DoCrc = (S#co_session.ctx)#sdo_ctx.use_crc andalso S#co_session.crc,
    GenCrc = ?UINT1(DoCrc),
    %% FIXME: Calculate the BlkSize from data
    BlkSize = co_session:next_blksize(S),
    S1 = S#co_session { crc=DoCrc, blkcrc=co_crc:init(), blksize=BlkSize},
    R = ?mk_scs_block_initiate_download_response(GenCrc,Ix,Si,BlkSize),
    send(S1, R),
    {next_state, s_block_download, S1, block_timeout(S1)}.


%%--------------------------------------------------------------------
%% @doc
%% Download block.<br/>
%% Expected events are:
%% <ul>
%% <li> block_segment</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_block_download </li>
%% <li> s_block_download_end </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_block_download(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_block_download(M, S) when is_record(M, can_frame) ->
    NextSeq = S#co_session.blkseq+1,
    BlkCrc = S#co_session.blkcrc,
    case M#can_frame.data of
	?ma_block_segment(Last,CliSeq,Data) when CliSeq =:= NextSeq ->
	    S1 = if Last =:= 1 ->
			 %% Don't add last block to crc until it
			 %% has been truncated
			 S#co_session {lastblk = Data};
		    S#co_session.crc->
			 S#co_session {blkcrc = co_crc:update(BlkCrc, Data)};
		    true ->
			  S
		 end,
	    case co_data_buf:write(S1#co_session.buf, Data, false, block) of
		{ok, Buf} ->
		    block_segment_written(S1#co_session {buf = Buf, last = Last});
		{ok, Buf, Mref} ->
		    ?dbg(srv, "s_block_download: mref=~p\n", [Mref]),
		    block_segment_written(S1#co_session {buf = Buf, 
							 last = Last, 
							 mref = Mref});
		{error, Reason} ->
		    ?dbg(srv, "s_block_download: write failed, reason = ~p", [Reason]),
		    abort(S, Reason)
	    end;
	?ma_block_segment(_Last,Seq,_Data) when Seq =:= 0; Seq > S#co_session.blksize ->
	    abort(S, ?abort_invalid_sequence_number);
	?ma_block_segment(_Last,_Seq,_Data) ->
	    %% here we could takecare of out of order data
	    abort(S, ?abort_invalid_sequence_number);
	%% Handle abort and spurious packets ...
	%% We can not use l_abort here because we do not know if message
	%% is an abort or not.
	_ ->
	    abort(S, ?abort_command_specifier)
    end;
s_block_download(timeout, S) ->
    abort(S, ?abort_timed_out).

block_segment_written(S) ->
    Last = S#co_session.last,
    NextSeq = S#co_session.blkseq + 1,
    if Last =:= 1; NextSeq =:= S#co_session.blksize ->
	    BlkSize = co_session:next_blksize(S),
	    S1 = S#co_session {blkseq=0, blksize=BlkSize},
	    R = ?mk_scs_block_download_response(NextSeq,BlkSize),
	    send(S1, R),
	    if Last =:= 1 ->
		    {next_state, s_block_download_end, S1,timeout(S1)};
	       true ->
		    {next_state, s_block_download, S1, timeout(S1)}
	    end;
       true ->
	    S1 = S#co_session {blkseq=NextSeq},
	    {next_state, s_block_download, S1, block_timeout(S1)}
    end.

%%--------------------------------------------------------------------
%% @doc
%% Download block end.<br/>
%% Expected events are:
%% <ul>
%% <li>block_download_end_request</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_writing_block_end </li>
%% <li> stop </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_block_download_end(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_block_download_end(M, 
		     S=#co_session {index = Ix, subind = Si, node_pid = NPid}) 
  when is_record(M, can_frame) ->
    case M#can_frame.data of
	?ma_ccs_block_download_end_request(N,RemoteCrc) ->
	    %% CRC 
	    NodeCrc = 
		if S#co_session.crc ->
			%% Calculate crc for last, maybe truncated, block
			CrcN = 7 - N,
			<<CrcData:CrcN/binary, _Pad/binary>> = S#co_session.lastblk,
			Crc = co_crc:update(S#co_session.blkcrc,CrcData),
			co_crc:final(Crc);
		   true ->
			%% If we should not calculate crc assume the received crc
			RemoteCrc
		end,
	    
	    case RemoteCrc of
		NodeCrc ->
		    %% CRC OK
		    case co_data_buf:write(S#co_session.buf,N,true,block) of	    
			{ok, Buf, Mref} ->
			    %% Called an application
			    ?dbg(srv, "s_block_download_end: mref=~p\n", [Mref]),
			    S1 = S#co_session {mref = Mref, buf = Buf},
			    {next_state, s_writing_block_end, S1, timeout(S1)};
			{ok, _Buf} -> 
			    co_api:object_event(NPid,{Ix, Si}),
			    co_api:session_over(NPid, normal),
			    R = ?mk_scs_block_download_end_response(),
			    send(S, R),
			    {stop, normal, S};
			{error, Reason} ->
			    ?dbg(srv, "s_block_download_end: write failed, reason = ~p", [Reason]),
			    abort(S, Reason)
		    end;
		_Crc ->
		    %% CRC not ok
		    ?dbg(srv, "s_block_download_end: crc error, remote crc = ~p, "
			 " node crc = ~p", [RemoteCrc, NodeCrc]),
		    abort(S, ?abort_crc_error)
	    end;
	_ ->
	    l_abort(M, S, s_block_download_end)
    end;
s_block_download_end(timeout, S) ->
    abort(S, ?abort_timed_out).    

%%--------------------------------------------------------------------
%% @doc
%% Initialize writing data to application.<br/>
%% Expected events are:
%% <ul>
%% <li>{Mref, {ok, Ref, WriteSze}}</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> s_block_download </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_writing_block_started(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_writing_block_started({Mref, Reply} = _M, S)  ->
    ?dbg(srv, "s_writing_block_started: Got event = ~p\n", [_M]),
    case {S#co_session.mref, Reply} of
	{Mref, {ok, _Ref, _WriteSze}} ->
	    erlang:demonitor(Mref, [flush]),
	    {ok, Buf} = co_data_buf:update(S#co_session.buf, Reply),
	    start_block_download(S#co_session {buf = Buf});
	_Other ->
	    ?dbg(srv, "s_writing_block_started: received = ~p, aborting", [_Other]),
	    abort(S, ?abort_internal_error)
    end;
s_writing_block_started(timeout, S) ->
    abort(S, ?abort_timed_out);
s_writing_block_started(M, S)  ->
    ?dbg(srv, "s_writing_block_started: Got event = ~p, aborting\n", [M]),
    demonitor_and_abort(M, S).

%%--------------------------------------------------------------------
%% @doc
%% Writing last data to application.<br/>
%% Expected events are:
%% <ul>
%% <li>{Mref, {ok, Ref}}</li>
%% </ul>
%% Next state can be:
%% <ul>
%% <li> stop </li>
%% </ul>
%% @end
%%--------------------------------------------------------------------
-spec s_writing_block_end(M::term(), S::#co_session{}) -> 
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

s_writing_block_end(timeout, S) ->
    abort(S, ?abort_timed_out);
s_writing_block_end(M, S)  ->
    %% All correct messages should be taken care of in handle_info()
    ?dbg(srv, "s_writing_block: Got event = ~p, aborting\n", [M]),
    demonitor_and_abort(M, S).


%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec handle_event(Event::term(), StateName::atom(), State::#co_session{}) ->
		       {next_state, NextState::atom(), NextS::#co_session{}} |
		       {next_state, NextState::atom(), NextS::#co_session{}, 
			Tout::timeout()} |
		       {stop, Reason::atom(), NextS::#co_session{}}.

handle_event(Event, StateName, S) ->
    ?dbg(srv, "handle_event: Got event ~p\n",[Event]),
    %% FIXME: handle abort here!!!
    apply(?MODULE, StateName, [Event, S]).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec handle_sync_event(Event::term(), From::{pid(), term()},
			StateName::atom(), State::#co_session{}) ->
		       {reply, ok, NextState::atom(), NextS::#co_session{}}.

handle_sync_event(_Event, _From, StateName, State) ->
    ?dbg(srv, "handle_sync_event: Got event ~p\n",[_Event]),
    {reply, ok, StateName, State}.

%%--------------------------------------------------------------------
%% @doc
%% This function is called by a gen_fsm when it receives any
%% message other than a synchronous or asynchronous event
%% (or a system message).
%%
%% NOTE!!! This actually is where all the replies from the application
%% are received. They are then normally sent on to the appropriate
%% state-function.
%% The exception is the reply to the read-call sent from co_data_buf as
%% this can arrive in any state and should just fill the buffer.
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_info(Info::term(), StateName::atom(), S::#co_session{}) ->
			 {next_state, NextState::atom(), NextS::#co_session{}} |
			 {next_state, NextState::atom(), NextS::#co_session{}, Tout::timeout()} |
			 {stop, Reason::atom(), NewS::#co_session{}}.
			 
handle_info({Mref, {ok, _Ref, _Data, _Eod} = Reply}, StateName, S) ->
    %% Streamed data read from application
    ?dbg(srv, "handle_info: Reply = ~p, State = ~p\n",[Reply, StateName]),
    case S#co_session.mref of
	Mref ->
	    erlang:demonitor(Mref, [flush]),
	    {ok, Buf} = co_data_buf:update(S#co_session.buf, Reply),
	    %% Fill data buffer if needed
	    case co_data_buf:load(Buf) of
		{ok, Buf1} ->
		    %% Buffer loaded
		    check_reading(StateName, S#co_session {buf = Buf1});
		{ok, Buf1, Mref1} ->
		    %% Wait for data ??
		    ?dbg(srv, "handle_info: mref=~p\n", [Mref]),
		    check_reading(StateName, S#co_session {buf = Buf1, 
							   mref = Mref1});
		{error, Reason} ->
		    ?dbg(srv, "handle_info: load failed, reason = ~p", [Reason]),
		    abort(S, Reason)
	    end;
	_OtherRef ->
	    %% Ignore reply
	    ?dbg(srv, "handle_info: wrong mref, ignoring\n",[]),
	    {next_state, StateName, S}
    end;
handle_info({_Mref, ok} = Info, StateName, S) 
  when StateName =:= s_writing_segment_end ->
    %% "Converting" info to event
    apply(?MODULE, StateName, [Info, S]);
handle_info({_Mref, ok} = Info, StateName, S) ->
    check_writing_block_end(Info, StateName, S);
handle_info({_Mref, {ok, Ref}} = Info, StateName, S) 
  when  is_reference(Ref) andalso
	StateName =:= s_writing_segment_end ->
    %% "Converting" info to event
    apply(?MODULE, StateName, [Info, S]);
handle_info({_Mref, {ok, Ref}} = Info, StateName, S) when is_reference(Ref) ->
    check_writing_block_end(Info, StateName, S);
handle_info({_Mref, {error, Error}}, _StateName, S) ->
    ?dbg(srv, "handle_info: received = ~p, aborting", [Error]),
    abort(S, Error);
handle_info({'DOWN',_Ref,process,_Pid,_Reason}, _StateName, S) ->
    ?dbg(srv, "handle_info: DOWN for process ~p received, aborting", [_Pid]),
    abort(S, ?abort_internal_error);
handle_info(Info, StateName, S) ->
    ?dbg(srv, "handle_info: Got info ~p\n",[Info]),
    %% "Converting" info to event
    apply(?MODULE, StateName, [Info, S]).


check_reading(s_reading_segment, S) ->
    read_segment(S);
check_reading(s_reading_block_segment, S) ->
    read_block_segment(S);
check_reading(State, S) -> 
    {next_state, State, S}.
	    

check_writing_block_end({Mref, Reply}, StateName, S) ->
    %% Streamed data write acknowledged
    ?dbg(srv, "check_writing_block_end: State = ~p\n",[StateName]),
    case S#co_session.mref of
	Mref ->
	    erlang:demonitor(Mref, [flush]),
	    case StateName of
		s_writing_block_end ->
		    ?dbg(srv, "handle_info: last reply, terminating\n",[]),
		    co_api:session_over(S#co_session.node_pid, normal),
		    R = ?mk_scs_block_download_end_response(),
		    send(S, R),
		    {stop, normal, S};
		State ->
		    {ok, Buf} = co_data_buf:update(S#co_session.buf, Reply),
		    {next_state, State, S#co_session {buf = Buf}}
	    end;
	_OtherRef ->
	    %% Ignore reply
	    ?dbg(srv, "handle_info: wrong mref, ignoring\n",[]),
	    {next_state, StateName, S}
    end.

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
-spec terminate(Reason::term(), StateName::atom(), S::#co_session{}) -> 
		       no_return().

terminate(_Reason, _StateName, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @end
%%--------------------------------------------------------------------
-spec code_change(OldVsn::term(), StateName::atom(), 
		  S::#co_session{}, Extra::term()) -> 
			 {ok, StateName::atom(), NewS::#co_session{}}.

code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
timeout(S) -> co_session:timeout(S).

block_timeout(S) -> co_session:block_timeout(S).

demonitor_and_abort(M, S) ->
    case S#co_session.mref of
	Mref when is_reference(Mref)->
	    erlang:demonitor(Mref, [flush]);
	_NoRef ->
	    do_nothing
    end,
    l_abort(M, S, s_reading).

l_abort(M, S, StateName) ->
    case M#can_frame.data of
	?ma_scs_abort_transfer(Ix,Si,_Code) when
	      Ix =:= S#co_session.index,
	      Si =:= S#co_session.subind ->
	    %% _Reason = co_sdo:decode_abort_code(Code),
	    %% remote party has aborted
	    %% If needed add:
	    %% co_api:session_over(S#co_session.node_pid, 
            %%                     {abort, {Ix, Si}, Code}),
	    {stop, normal, S};	    
	?ma_scs_abort_transfer(_Ix,_Si,_Code) ->
	    %% probably a delayed abort for an old session ignore
	    {next_state, StateName, S, timeout(S)};
	_ ->
	    %% we did not expect this command abort
	    abort(S, ?abort_command_specifier)
    end.
	    

abort(S=#co_session {index = Ix, subind = Si, buf = Buf}, Reason) ->
    Code = co_sdo:encode_abort_code(Reason),
    co_data_buf:abort(Buf, Code),
    co_api:session_over(S#co_session.node_pid, {abort, {Ix, Si}, Code}),
    R = ?mk_ccs_abort_transfer(Ix, Si, Code),
    send(S, R),
    {stop, normal, S}.
    

send(S, Data) when is_binary(Data) ->
    ?dbg(srv, "send: ~s\n", [co_format:format_sdo(co_sdo:decode_tx(Data))]),
    co_session:send(S, Data).

