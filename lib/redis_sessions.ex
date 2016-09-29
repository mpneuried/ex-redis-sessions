defmodule RedisSessions do
	@moduledoc """
	Redis Sessions base module to handle the GenServer
	"""
	use Application

	# See http://elixir-lang.org/docs/stable/elixir/Application.html
	# for more information on OTP Applications
	def start( _type, _args ) do
		start_link
	end



	def start_link( opts \\ [ ] ) do
		import Supervisor.Spec, warn: false

		# Define workers and child supervisors to be supervised
		children = [
			supervisor( RedisSessions.RedixPool, [ ] ),
			worker( RedisSessions.Client, [ ], restart: :transient )
		]

		# See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
		# for other strategies and supported options
		opts = [ strategy: :one_for_one, name: RedisSessions.Supervisor ]
		Supervisor.start_link( children, opts )
	end
end
