defmodule RedisSessions.Client do
	@moduledoc ~S"""
	The Client module contains functions to interact with the sessions.
	"""
	@type app :: String.t
	@type id :: String.t
	@type ip :: {integer, integer, integer, integer}
	
	use GenServer
	
	#alias RedisSessions.RedixPool, as: Redis
	
	@doc """
	Create a session

	## Parameters

	* `app` (Binary) The app id (namespace) for this session.
	* `id` (Binary) The user id of this user. Note: There can be multiple sessions for the same user id. If the user uses multiple client devices.
	* `ip` (Binary) IP address of the user. This is used to show all ips from which the user is logged in.
	* `ttl` (Integer) *optional* The "Time-To-Live" for the session in seconds. Default: 7200.
	* `data` (Map) *optional* Additional data to set for this sessions. (see the "set" method)
	
	## Examples
	
		iex> RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600 )
		{:ok, "OK"}
	"""
	@spec create( app, id, ip, integer, Map.t ) :: boolean
	
	def create( app, id, ip, ttl \\ 3600, data \\ nil ) do
		GenServer.call( __MODULE__,{ :create, {app, id, ip, ttl}} )
	end
	
	# def set( app, token, data ) do
	# 	
	# end
	# 
	# def get( app, token ) do
	# 	
	# end
	# 
	# def kill( app, token ) do
	# 	
	# end
	# 
	# def activity( app, dt \\ 600 ) do
	# 	
	# end
	# 
	# def soapp( app, dt \\ 600 ) do
	# 	
	# end
	# 
	# def soid( app, id ) do
	# 	
	# end
	# 
	# def killsoid( app, id ) do
	# 	
	# end
	# 
	# def killall( app ) do
	# 	
	# end
	
	####
	# GENSERVER API
	####
	
	@doc """
	start genserver
	"""
	@spec start() :: true
	def start() do
		GenServer.start_link( __MODULE__, [])
	end
	
	@doc """
	init the module
	"""
	@spec init( any ) :: {:ok, integer}
	def init( _ ) do
		state = %{}
		
		{:ok, state }
	end
	
	def handle_call( {:create, args}, from, opts ) do
		IO.inspect from
		IO.inspect opts
		{:reply, "OK", opts}
	end
	
end
