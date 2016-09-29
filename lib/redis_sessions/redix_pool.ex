defmodule RedisSessions.RedixPool do
	@moduledoc """
	A library of functions used to create and use a Redis pool through Redix.
	"""

	use Supervisor

	####
	# SUPERVISOR API
	####

	@doc """
	start supervisor
	"""
	def start_link do
		Supervisor.start_link( __MODULE__, [ ] )
	end

	@doc """
	init redix pool
	"""
	def init( _ ) do
		pool_opts = [
			name: { :local, :redix_poolboy },
			worker_module: Redix,
			size: Application.get_env( :redis_sessions, :pool_size, 10 ),
			max_overflow: Application.get_env( :redis_sessions, :pool_overflow, 5 )
		]

		children = [
			:poolboy.child_spec( :redix_poolboy, pool_opts,	Application.get_env( :redis_sessions, :redis, [ ] ) )
		]

		supervise( children, strategy: :one_for_one, name: __MODULE__ )
	end

	@doc """
	execute a singleredis command

	## Examples

		iex> RedisSessions.RedixPool.command ~w(PING)
		{:ok, "PONG"}
	"""
	def command( command ) do
		:poolboy.transaction( :redix_poolboy, &Redix.command( &1, command ) )
	end

	@doc """

	execute mutliple redis commands at once.

	## Examples
		iex> RedisSessions.RedixPool.pipeline( [ ~w(SET redissessions-test woohoo!), ~w(GET redissessions-test), ~w(DEL redissessions-test)] )
		{:ok, ["OK", "woohoo!", 1] }
		iex> RedisSessions.RedixPool.pipeline( [ [ "SET", "redissessions-list", "woohoo!"], ["GET", "redissessions-list"], [ "DEL", "redissessions-list" ]] )
		{:ok, ["OK", "woohoo!", 1] }
	"""
	def pipeline( commands )  do
		:poolboy.transaction( :redix_poolboy, &Redix.pipeline( &1, commands ) ) 
	end
end
