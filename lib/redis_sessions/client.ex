defmodule RedisSessions.Client do
	@moduledoc ~S"""
	The Client module contains functions to interact with the sessions.
	"""
	@type app :: String.t
	@type id :: String.t
	@type token :: String.t
	@type session :: %{ id: String.t, r: integer, w: integer, idle: integer, ttl: integer, d: Map.t }
	@type ip :: { integer, integer, integer, integer }

	@tokenchars "ABCDEFGHIJKLMNOPQRSTUVWabcdefghijklmnopqrstuvw0123456789" |> String.split( "", trim: true )
	@redisns Application.get_env( :redis_sessions, :ns, "rs" ) <> ":"

	use GenServer
	import Logger

	alias RedisSessions.RedixPool, as: Redis

	@doc """
	Create a session

	## Parameters

	* `app` (Binary) The app id (namespace) for this session. Must be [a-zA-Z0-9_-] and 3-20 chars long.
	* `id` (Binary) The user id of this user. Note: There can be multiple sessions for the same user id. If the user uses multiple client devices.
	* `ip` (Binary) IP address of the user. This is used to show all ips from which the user is logged in.
	* `ttl` (Integer) *optional* The "Time-To-Live" for the session in seconds. Default: 7200.
	* `d` (Map) *optional* Additional data to set for this sessions. (see the "set" method)

	## Examples
		{:ok, %{token: token}} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ "foo" => "bar", "ping" => "pong"} )
	"""
	@spec create( app, id, ip, integer, Map.t, node) :: boolean
	def create( app, id, ip, ttl \\ 3600, data \\ nil, server \\ node()  ) do
		GenServer.call( { __MODULE__, server }, { :create, { app, id, ip, ttl, data } } )
	end

	@doc """
	Set/Update/Delete custom data for a single session.
	All custom data is stored in the `d` object which is a simple hash object structure.

	`d` might contain a map with **one or more** keys with the following types: `binary`, `number`, `boolean`, `nil`.
	Keys with all values except `nil` will be stored. If a key containts `nil` the key will be removed.

	Note: If `d` already contains keys that are not supplied in the set request then these keys will be untouched.

	## Parameters

	* `app` (Binary) The app id (namespace) for this session. Must be [a-zA-Z0-9_-] and 3-20 chars long.
	* `token` (Binary) The generated session token. Must be [a-zA-Z0-9] and 64 chars long
	* `d` (Map) *optional* Data to set. Must be a map with keys whose values only consist of binaries, numbers, boolean and nil.

	## Returns

	`{:ok, session }` the session data after change

	## Examples

		{:ok, token} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ "foo" => "bar"} )
		RedisSessions.Client.set( "exrs-test", token, %{ "foo" => "buzz"} )
		# {:ok, %{ id: "foo", r:1, w:2, idle: 3, ttl: 3600, d: %{"foo" => "buzz"} }}

	"""
	@spec set( app, token, Map.t, node) :: {:ok, session} | { :error, String.t }
	def set( app, token, data \\ nil, server \\ node() ) do
		GenServer.call( { __MODULE__, server }, { :set, { app, token, data } } )
	end

	@doc """

	Get a session for an app and token

	## Parameters

	* `app` (Binary) The app id (namespace) for this session. Must be [a-zA-Z0-9_-] and 3-20 chars long.
	* `token` (Binary) The generated session token. Must be [a-zA-Z0-9] and 64 chars long

	## Examples

		{:ok, %{ token: token }} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ "foo" => "bar"} )
		RedisSessions.Client.get( "exrs-test", token )
		# {:ok, %{ id: "foo", r: 2, w: 1, idle: 1, ttl: 3600, ip: "127.0.0.1", d: %{"foo" => "bar"} }}
	"""
	@spec get( app, token, node) :: {:ok, session} | { :error, String.t }
	def get( app, token, server \\ node() ) do
		GenServer.call( { __MODULE__, server }, { :get, { app, token, false } } )
	end

	@doc """
	Kill a session for an app and token.

	## Parameters

	* `app` (Binary) The app id (namespace) for this session. Must be [a-zA-Z0-9_-] and 3-20 chars long.
	* `token` (Binary) The generated session token. Must be [a-zA-Z0-9] and 64 chars long

	## Examples

		iex>{:ok, %{token: token}} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ "foo" => "bar"} )
		...>RedisSessions.Client.kill( "exrs-test", token )
		{:ok, %{kill: 1} }
	"""
	@spec kill( app, token, node) :: { :kill, integer } | { :error, String.t }
	def kill( app, token, server \\ node() ) do
		GenServer.call( { __MODULE__, server }, { :kill, { app, token } } )
	end

	@doc """
	Query the amount of active session within the last 10 minutes (600 seconds). Note: Multiple sessions from the same user id will be counted as one.

	## Parameters

	* `app` (Binary) The app id (namespace) for this session. Must be [a-zA-Z0-9_-] and 3-20 chars long.
	* `dt` (Integer) Delta time. Amount of seconds to check (e.g. 600 for the last 10 min.)

	## Examples

		iex>{:ok, _} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ "foo" => "bar"} )
		...>RedisSessions.Client.activity( "exrs-test" )
		{:ok, %{activity: 1}}
	"""
	@spec activity( app, integer, node) :: { :ok, integer } | { :error, String.t }
	def activity( app, dt \\ 600, server \\ node() ) do
		GenServer.call( { __MODULE__, server }, { :activity, { app, dt } } )
	end

	@doc """
	Get all sessions of an app there were active within the last 10 minutes (600 seconds).

	## Parameters

	* `app` (Binary) The app id (namespace) for this session. Must be [a-zA-Z0-9_-] and 3-20 chars long.
	* `dt` (Integer) Delta time. Amount of seconds to check (e.g. 600 for the last 10 min.)

	## Examples

		iex>{:ok, tokenA} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600 )
		...>{:ok, tokenB} = RedisSessions.Client.create( "exrs-test", "bar", "127.0.0.1", 3600 )
		...>RedisSessions.Client.soapp( "exrs-test" )
		{:ok, %{ sessions: [ %{ id: "foo", r: 1, w: 1, idle: 1, ttl: 3600, d: nil }, %{ id: "bar", r: 1, w: 1, idle: 1, ttl: 3600, d: nil } ] } }
	"""
	@spec soapp( app, integer, node) :: { :ok, [ session ] } | { :error, String.t }
	def soapp( app, dt \\ 600, server \\ node() ) do
		GenServer.call( { __MODULE__, server }, { :soapp, { app, dt } } )
	end

	@doc """
	Get all sessions within an app that belong to a single id. This would be all sessions of a single user in case he is logged in on different browsers / devices.

	## Parameters

	* `app` (Binary) The app id (namespace) for this session. Must be [a-zA-Z0-9_-] and 3-20 chars long.
	* `id` (Binary) The user id of this user.

	## Examples

		iex>{:ok, tokenA1} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600 )
		...>{:ok, tokenB1} = RedisSessions.Client.create( "exrs-test", "bar", "127.0.0.1", 3600 )
		...>{:ok, tokenA2} = RedisSessions.Client.create( "exrs-test", "foo", "192.168.0.42", 3600 )
		...>RedisSessions.Client.soid( "exrs-test", "foo" )
		{:ok, [ %{ id: "foo", r:1, w:1, idle: 1, ttl: 3600 }, %{ id: "bar", r:1, w:1, idle: 1, ttl: 3600 } ] }
	"""
	@spec soid( app, id, node) :: { :ok, [ session ] } | { :error, String.t }
	def soid( app, id, server \\ node() ) do
		GenServer.call( { __MODULE__, server }, { :soid, { app, id } } )
	end

	@doc """
	Kill all sessions of an id within an app

	## Parameters

	* `app` (Binary) The app id (namespace) for this session. Must be [a-zA-Z0-9_-] and 3-20 chars long.
	* `id` (Binary) The user id of this user.

	## Examples

		iex>{:ok, tokenA1} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600 )
		...>{:ok, tokenB1} = RedisSessions.Client.create( "exrs-test", "bar", "127.0.0.1", 3600 )
		...>{:ok, tokenA2} = RedisSessions.Client.create( "exrs-test", "foo", "192.168.0.42", 3600 )
		...>{:ok, tokenA2} = RedisSessions.Client.create( "exrs-test2", "foo", "192.168.0.42", 3600 )
		...>RedisSessions.Client.killsoid( "exrs-test", "foo" )
		{:ok, %{ kill: 2 }}

	"""
	@spec killsoid( app, id, node) :: { :kill, integer } | { :error, String.t }
	def killsoid( app, id, server \\ node() ) do
		GenServer.call( { __MODULE__, server }, { :killsoid, { app, id } } )
	end

	@doc """
	Kill all sessions of an app

	## Parameters

	* `app` (Binary) The app id (namespace) for this session. Must be [a-zA-Z0-9_-] and 3-20 chars long.

	## Examples

		iex>{:ok, tokenA1} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600 )
		...>{:ok, tokenB1} = RedisSessions.Client.create( "exrs-test", "bar", "127.0.0.1", 3600 )
		...>{:ok, tokenA2} = RedisSessions.Client.create( "exrs-test", "foo", "192.168.0.42", 3600 )
		...>{:ok, tokenA2} = RedisSessions.Client.create( "exrs-test2", "foo", "192.168.0.42", 3600 )
		...>RedisSessions.Client.killall( "exrs-test" )
		{:ok, %{ kill: 3 }}
	"""
	@spec killall( app, node) :: { :kill, integer } | { :error, String.t }
	def killall( app, server \\ node() ) do
		GenServer.call( { __MODULE__, server }, { :killall, { app } } )
	end


	@doc """
	Wipe all deprecated sessions

	## Parameters
	"""
	@spec wipe( node ) :: :ok
	def wipe( server \\ node() ) do
		GenServer.cast( { __MODULE__, server }, { :wipe } )
		:ok
	end
	
	####
	# GENSERVER API
	####

	@doc """
	start genserver
	"""
	@spec start_link() :: true
	def start_link() do
		
		interval = Application.get_env( :redis_sessions, :wipe, 600 ) * 1000
		
		:timer.apply_interval(interval, __MODULE__, :wipe, [])
		
		GenServer.start_link( __MODULE__, [], name: __MODULE__)
	end

	def handle_call( {:create, { app, id, ip, ttl, data } }, _from, opts ) do
		case Vex.errors( [ app: app, id: id, ip: ip, ttl: ttl, d: data ],
			app: validate( :app ),
			id: validate( :id ),
			ip: validate( :ip ),
			ttl: validate( :ttl ),
			d: validate( :d )
		) do
			[] ->
				debug "create session of app `#{app}` with id: `#{id}` from ip: `#{ip}`"
				now = DateTime.utc_now()

				token = create_token( now )

				thesession = []
				if not is_nil( data ) do
					# filter nil values from data
					data = d_filter_nil( data )
					if data !== %{} do
						thesession = [ "d", Poison.encode!( data ) ]
					end
				end

				thesession = [ "HMSET", "#{@redisns}#{app}:#{token}", "id", id, "r", 1, "w", 1, "ip", ip, "la", ts( now, :seconds ), "ttl", ttl | thesession ]
				mc = create_multi_statement( [ [ "SADD", "#{@redisns}#{app}:us:#{id}", token ], thesession ], { app, token, id, ttl }, now )

				case Redis.pipeline( mc ) do
					{ :ok, [ _, _, _, _, "OK" ]} ->
						{ :reply, { :ok, %{ token: token } }, opts}
					{ :ok, [ _, _, _, _, error ]} ->
						{ :reply, { :error, error }, opts }
					{ :error, error} ->
						{ :reply, { :error, error }, opts }
				end
			errors -> handle_validation_errors( errors, opts )
		end
	end

	def handle_call( {:set, {app, token, data}}, _from, opts ) do
		case Vex.errors( [ app: app, token: token, d: data ],
			app: validate( :app ),
			token: validate( :token ),
			d: validate( :d )
		) do
			[] ->
				debug "update session of app `#{app}` with token: `#{token}`"
				case session_get( app, token, true ) do
					{:ok, %{}=session} ->
						
						now = DateTime.utc_now()
						thekey = "#{@redisns}#{app}:#{token}"
						cmds = []
						if not is_nil( data ) do
							# filter nil values from data
							nil_keys = map_get_nil_keys( data )
							data = Map.merge( Map.drop( session.d, nil_keys ), Map.drop( data, nil_keys ) )
							
							if data !== %{} do
								cmds = [ [ "HSET", thekey, "d", Poison.encode!( data ) ] | cmds ]
								session = Map.put( session, :d, data )
							else
								cmds = [ [ "HDEL", thekey, "d" ] | cmds ]
								session = Map.put( session, :d, nil )
							end
						else
							cmds = [ [ "HDEL", thekey, "d" ] | cmds ]
							session = Map.put( session, :d, nil )
						end
						
						if session.idle > 1 do
							cmds = [ [ "HSET", thekey, "la", ts( now, :seconds ) ] | cmds ]
						end
						
						cmds = [ [ "HINCRBY", thekey, "w", 1 ] | cmds ]
						session = Map.update!( session, :w, &(&1+1) )
						
						mc = create_multi_statement( cmds, { app, token, session.id, session.ttl }, now )
						
						debug "update session of app `#{app}` write id `#{session.id}`"
						
						case Redis.pipeline( mc ) do
							{ :ok, _} ->
								{ :reply, { :ok, session }, opts }
							{ :error, error} ->
								{ :reply, { :error, error }, opts }
						end

					reply ->
						{ :reply, reply, opts }
				end
			errors -> handle_validation_errors( errors, opts )
		end
	end

	def handle_call( {:get, {app, token, noupdate}}, _from, opts ) do
		case Vex.errors( [ app: app, token: token ],
			app: validate( :app ),
			token: validate( :token )
		) do
			[] ->
				debug "get session of app `#{app}` with token: `#{token}`"
				{ :reply, session_get( app, token, noupdate ), opts }
			errors -> handle_validation_errors( errors, opts )
		end
	end

	def handle_call( {:kill, { app, token }}, _from, opts ) do
		#IO.inspect args
		case Vex.errors( [ app: app, token: token ],
			app: validate( :app ),
			token: validate( :token )
		) do
			[] ->
				debug "kill session of app `#{app}` with token: `#{token}`"
				case session_get( app, token, true ) do
					{:ok, %{}=session} ->
						
						case kill_sessions( app, token, session.id ) do
							{ :ok, resutl} ->
								{ :reply, { :ok, resutl }, opts }
							{ :error, error} ->
								{ :reply, { :error, error }, opts }
						end

					reply ->
						{ :reply, reply, opts }
				end
			errors -> handle_validation_errors( errors, opts )
		end
	end

	def handle_call( {:activity, {app, dt}}, _from, opts ) do
		case Vex.errors( [ app: app, dt: dt ],
			app: validate( :app ),
			dt: validate( :dt )
		) do
			[] ->
				debug "get app `#{app}` activity"
				case Redis.command [ "ZCOUNT", "#{@redisns}#{app}:_users", (DateTime.utc_now() |> ts) - dt, "+inf" ] do
					{ :ok, result } ->
						{:reply, {:ok, %{activity: result}}, opts}
					{ :error, error} ->
						{:reply, {:error, error}, opts}
				end
			errors -> handle_validation_errors( errors, opts )
		end
	end

	def handle_call( {:soapp, {app, dt}}, _from, opts ) do
		case Vex.errors( [ app: app, dt: dt ],
			app: validate( :app ),
			dt: validate( :dt )
		) do
			[] ->
				debug "kill all sessions of app `#{app}`"
				case Redis.command [ "ZREVRANGEBYSCORE", "#{@redisns}#{app}:_sessions", "+inf", (DateTime.utc_now() |> ts) - dt ] do
					{ :ok, result } ->
						sessions = result
							|> Enum.map( &(Enum.at( String.split(&1, ":" ), 0)) )
						{:reply, grep_sessions( app, sessions ), opts}
					{ :error, error} ->
						{:reply, {:error, error}, opts}
				end
			errors -> handle_validation_errors( errors, opts )
		end
	end

	def handle_call( {:soid, {app, id}}, _from, opts ) do
		case Vex.errors( [ app: app, id: id ],
			app: validate( :app ),
			id: validate( :id )
		) do
			[] ->
				debug "get all session of app `#{app}` with id: `#{id}`"
				case sessions_of_id( app, id ) do
					{ :ok, result } ->
						{:reply, result, opts}
					{ :error, error} ->
						{:reply, error, opts}
				end
			errors -> handle_validation_errors( errors, opts )
		end
	end

	def handle_call( {:killsoid, {app, id}}, _from, opts ) do
		case Vex.errors( [ app: app, id: id ],
			app: validate( :app ),
			id: validate( :id )
		) do
			[] ->
				debug "kill all session of app `#{app}` with id: `#{id}`"
				case session_tokens( app, id ) do
					{ :ok, [] } ->
						{:reply, { :ok, %{ kill: 0} }, opts}
					{ :ok, tokens } ->
						{:reply, kill_sessions( app, tokens, id), opts}
					{ :error, error} ->
						{:reply, error, opts}
				end
			errors -> handle_validation_errors( errors, opts )
		end
	end

	def handle_call( {:killall, {app}}, _from, opts ) do
		case Vex.errors( [ app: app],
			app: validate( :app )
		) do
			[] ->
				debug "kill all session of app `#{app}`"
				case kill_all( app ) do
					{ :ok, [] } ->
						{:reply, { :ok, %{ kill: 0} }, opts}
					{ :ok, resp } ->
						{:reply, { :ok, resp } , opts}
					{ :error, error} ->
						{:reply, error, opts}
				end
			errors -> handle_validation_errors( errors, opts )
		end
	end
	
	def handle_cast( {:wipe}, opts ) do
		debug "wipe session call"
		case Redis.command [ "ZRANGEBYSCORE", "#{@redisns}SESSIONS", "-inf", (DateTime.utc_now() |> ts) ] do
			{ :ok, [] } ->
				debug "wipe sessions empty"
			{ :ok, sessions } ->
				
				info "wipe #{Enum.count( sessions )} sessions"
				
				sessions
					|> Enum.map( fn( session )->
						[ app, token, id ] = String.split( session, ":" )
						kill_sessions( app, token, id )
					end )
				
			{ :error, err} ->
				error err
		end
		
		{:noreply, opts}
	end



	####
	# PRIVATE METHODS
	####
	
	defp session_get( app, token, noupdate ) do
		cmd = [ "HMGET", "#{@redisns}#{app}:#{token}", "id", "r", "w", "ttl", "d", "la", "ip" ]
		case Redis.command( cmd ) do
			{ :ok, result } ->
				
				session = prepare_session( result )
				cond do
					nil === session ->
						{ :ok, nil }
					noupdate ->
						{ :ok, session }
					%{} = session ->
						case update_counter( app, token, session, :r ) do
							{:error, error } ->
								{ :error, error }
							session ->
								{ :ok, session }
						end
				end
				
			{ :error, error} ->
				{:error, error}
		end
	end

	defp create_multi_statement( mc, { app, token, id, ttl }, date \\ DateTime.utc_now() ) do
		now = ts( date )

		mc = [ ["ZADD", "#{@redisns}SESSIONS", "#{now}#{ttl}", "#{app}:#{token}:#{id}"] | mc ]
		mc = [ ["ZADD", "#{@redisns}#{app}:_users", now, id] | mc ]
		mc = [ ["ZADD", "#{@redisns}#{app}:_sessions", now, "#{token}:#{id}"] | mc ]
		mc
	end

	defp create_token( date \\ DateTime.utc_now() ) do
		random_string() <> "Z" <> str36_datetime( date )
	end

	defp prepare_session( [ id, r, w, ttl, d, la, ip ] ) do
		now = DateTime.utc_now()
		case id do
			nil -> nil
			_ ->
				session = %{
					id: id,
					r: String.to_integer( r ),
					w: String.to_integer( w ),
					ttl: String.to_integer( ttl ),
					idle: ts( now, :seconds ) - String.to_integer( la ),
					ip: ip
				}
				
				if d do
					session = Map.put( session, :d, Poison.decode!( d ) )
				else
					session = Map.put( session, :d, nil )
				end
				
				cond do
					session.ttl < session.idle -> nil
					true -> session
				end
		end
	end
	
	defp kill_sessions( app, token, id ) do
		case token do
			tkn when is_binary( token ) ->
				mc = create_kill_statement( app, tkn, id )
			tokens when is_list( token ) ->
				mc = tokens
					|> Enum.reduce( [], &( &2 ++ create_kill_statement( app, &1, id ) ) )
		end
		
		mc = mc ++ [["EXISTS", "#{@redisns}#{app}:us:#{id}"]]
		
		case Redis.pipeline( mc ) do
			{ :ok, results } ->
				deleted = results
					|> Enum.chunk( 4 )
					|> Enum.reduce( 0, fn( [ _, _, _, deleted ], acc ) -> acc + deleted end )
				
				case Redis.command [ "ZREM", "#{@redisns}#{app}:_users", id ] do
					{ :ok, _ } ->
						{:ok, %{kill: deleted } }
					{ :error, error } ->
						{:error, error }
				end
			{ :error, error } ->
				{:error, error }
		end
	end
	
	defp create_kill_statement( app, token, id ) do
		[
			["ZREM", "#{@redisns}#{app}:_sessions", "#{token}:#{id}"],
			["SREM", "#{@redisns}#{app}:us:#{id}", token],
			["ZREM", "#{@redisns}SESSIONS", "#{app}:#{token}:#{id}"],
			["DEL", "#{@redisns}#{app}:#{token}"]
		]
	end
	
	defp kill_all( app ) do
		
		ask = "#{@redisns}#{app}:_sessions"
		
		case Redis.command [ "ZRANGE", ask, 0, -1 ] do
			{ :ok, [] } ->
				{:ok, %{ kill: 0} }
			{ :ok, sessions } ->
				
				{ gk, tk, uk, ids } = sessions
					|> Enum.reduce( { [], [], %MapSet{}, %MapSet{} }, fn( session, { gk, tk, uk, ids } )->
						[ token, id ] = String.split( session, ":" )
						
						gk = [ "#{app}:#{session}" | gk ]
						tk = [ "#{@redisns}#{app}:#{token}" | tk ]
						
						uk = MapSet.put( uk, "#{@redisns}#{app}:us:#{id}" )
						ids = MapSet.put( ids, id )
						
						{ gk, tk, uk, ids }
					end )
					
				mc = [
					[ "ZREM", ask | sessions ],
					[ "ZREM", "#{@redisns}#{app}:_users" | MapSet.to_list( ids ) ],
					[ "ZREM", "#{@redisns}SESSIONS" | gk ],
					[ "DEL" | MapSet.to_list( uk ) ],
					[ "DEL" | tk ]
				]
				
				case Redis.pipeline( mc ) do
					{ :ok, [ count | _t ] } ->
						{:ok, %{ kill: count} }
					{ :error, error } ->
						{:error, error }
				end
			{ :error, error} ->
				{:error, error}
		end
	end
	
	defp session_tokens( app, id ) do
		case Redis.command [ "SMEMBERS", "#{@redisns}#{app}:us:#{id}" ] do
			{ :ok, tokens } ->
				{:ok, tokens }
			{ :error, error} ->
				{:error, error}
		end
	end
	
	defp sessions_of_id( app, id ) do
		case session_tokens( app, id ) do
			{ :ok, tokens } ->
				{:ok, grep_sessions( app, tokens ) }
			{ :error, error} ->
				{:error, error}
		end
	end

	defp update_counter( app, token, session, key, inc \\ 1 ) do
		session = Map.update!( session, key, &(&1 + inc) )

		cmd = ["hincrby", "#{@redisns}#{app}:#{token}", Atom.to_string( key ), inc]

		case Redis.command( cmd ) do
			{ :ok, _ } ->
				session
			{ :error, error } ->
				{:error, error }
		end
	end
	
	defp grep_sessions( _app, [] ) do
		{ :ok, %{ sessions: [] } }
	end
	
	defp grep_sessions( app, sessions ) do
		mc = sessions
			|> Enum.map( &( ["hmget", "#{@redisns}#{app}:#{&1}", "id", "r", "w", "ttl", "d", "la", "ip"] ) )
		case Redis.pipeline( mc ) do
			{ :ok, sessiondatas } ->
				ret = sessiondatas
					|> Enum.filter( &( &1 != nil ) )
					|> Enum.map( &( prepare_session( &1 ) ) )
				{ :ok, %{ sessions: ret } }
			{ :error, error } ->
				{:error, error }
		end
	end
	
	defp d_filter_nil( data ) do
		Enum.filter( data, fn( { _, val } )->
			not is_nil( val )
		end ) |> Enum.reduce( %{}, fn( { key, val }, acc ) ->
			Map.put( acc, key, val )
		end )
	end
	
	defp map_get_nil_keys( data ) do
		data
			|> Enum.filter( fn( { _, val } )->is_nil( val ) end)
			|> Enum.reduce( [], fn ({key,_}, acc)-> [key|acc] end ) 
	end
	
	defp handle_validation_errors( errors, opts ) do
		case errormsg( errors ) do
			errors when is_list( errors ) ->
				{ :reply, { :error, errors }, opts }
			errors ->
				{ :reply, { :error, [errors] }, opts }
		end
	end
	
	defp validate( :app ) do
		[
			presence: true,
			format: [ with: ~r/^([a-zA-Z0-9_-]){3,20}$/]
		]
	end

	defp validate( :id ) do
		[
			presence: true,
			format: [ with: ~r/^([a-zA-Z0-9_-]){1,64}$/]
		]
	end

	defp validate( :ip ) do
		[
			presence: true,
			format: [ with: ~r/^.{1,39}$/]
		]
	end

	defp validate( :ttl ) do
		[
			presence: true,
			by: [function: &( is_integer( &1 ) and &1 > 10 )]
		]
	end

	defp validate( :token ) do
		[
			presence: true,
			format: [ with: ~r/^([a-zA-Z0-9]){64}$/i]
		]
	end

	defp validate( :dt ) do
		[
			presence: true,
			by: [function: &( is_integer( &1 ) and &1 > 10 )]
		]
	end

	defp validate( :d ) do
		[
			by: [function: &is_map/1, allow_nil: true]
		]
	end

	defp validate( :d_req ) do
		[
			by: [function: &is_map/1]
			# TODO add a more detailed validation. see https://github.com/smrchy/redis-sessions/blob/master/index.coffee#L613
		]
	end

	defp errormsg( errors ) when is_list( errors ) do
		errors
			|> Enum.map( fn( error )->
				errormsg( error )
			end )
	end

	defp errormsg( {_err, key, type, msg } ) do
		case { key, type } do
			{:app, :format} ->
				{ key, :invalidFormat, "Invalid app format" }
			{:app, :presence} ->
				{ key, :missingParameter, "no app supplied" }
			{:id, :format} ->
				{ key, :invalidFormat, "Invalid id format" }
			{:id, :presence} ->
				{ key, :missingParameter, "no id supplied" }
			{:ip, :format} ->
				{ key, :invalidFormat, "Invalid ip format" }
			{:ip, :presence} ->
				{ key, :missingParameter, "no ip supplied" }
			{:token, :format} ->
				{ key, :invalidFormat, "Invalid token format" }
			{:token, :presence} ->
				{ key, :missingParameter, "no token supplied" }
			{:ttl, :by} ->
				{ key, :invalidValue, "ttl must be a positive integer >= 10" }
			{:dt, :by} ->
				{ key, :invalidValue, "ttl must be a positive integer >= 10" }
			{:d, :by} ->
				{ key, :invalidValue, "d must be an object" }
			_ ->
				{ key, :invalid, msg }
		end
   end

	defp random_string( length \\ 55, chars \\ @tokenchars ) do
		1..length |> Enum.map_join( fn (_) -> Enum.random( chars ) end)
	end

	defp ts( date \\ DateTime.utc_now(), resolution \\ :milliseconds  ) do
		date |> DateTime.to_unix( resolution )
	end

	defp str36_datetime( date \\ DateTime.utc_now() ) do
		ts( date )
			|> Integer.to_string( 36 )
			|> String.downcase()
	end

end
