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
			name: { :local, __MODULE__ },
			worker_module: Redix,
			size: get_poolsize( ),
			max_overflow: get_pooloverflow( )
		]
		
		children = [
			:poolboy.child_spec( __MODULE__ , pool_opts, get_redisurl( ) )
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
		:poolboy.transaction( __MODULE__, &Redix.command( &1, command ) )
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
		:poolboy.transaction( __MODULE__, &Redix.pipeline( &1, commands ) ) 
	end
	
	
	defp get_poolsize do
		get_poolsize( Application.get_env( :redis_sessions, :pool_size, 10 ) )
	end
	
	defp get_poolsize( poolsize ) when is_binary( poolsize ) do
		String.to_integer( poolsize )
	end
	
	defp get_poolsize( poolsize ) when is_number( poolsize ) do
		poolsize
	end
	
	defp get_poolsize( { :system, envvar } ) do
		get_poolsize( { :system, envvar, 10 } )
	end
	
	defp get_poolsize( { :system, envvar, default } ) do
		sysvar = System.get_env( envvar )
		if sysvar == nil do
			default
		else
			sysvar
		end
	end
	
	defp get_pooloverflow do
		get_pooloverflow( Application.get_env( :redis_sessions, :pool_overflow, 5 ) )
	end
	
	defp get_pooloverflow( pooloverflow ) when is_binary( pooloverflow ) do
		String.to_integer( pooloverflow )
	end
	
	defp get_pooloverflow( pooloverflow ) when is_number( pooloverflow ) do
		pooloverflow
	end
	
	defp get_pooloverflow( { :system, envvar } ) do
		get_pooloverflow( { :system, envvar, 5 } )
	end
	
	defp get_pooloverflow( { :system, envvar, default } ) do
		sysvar = System.get_env( envvar )
		if sysvar == nil do
			default
		else
			sysvar
		end
	end
	
	defp get_redisurl do
		get_redisurl( Application.get_env( :redis_sessions, :redis, "redis://localhost:6379/0" ) )
	end
	
	defp get_redisurl( redisurl ) when is_binary( redisurl ) do
		redisurl
	end
	
	defp get_redisurl( { :system, envvar } ) do
		get_redisurl( { :system, envvar, "redis://localhost:6379/0" } )
	end
	
	defp get_redisurl( { :system, envvar, default } ) do
		sysvar = System.get_env( envvar )
		if sysvar == nil do
			default
		else
			sysvar
		end
	end
end
