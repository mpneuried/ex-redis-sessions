defmodule RedisSessions.ClientTest do
	use ExUnit.Case
	doctest RedisSessions.Client, only: [create: 6]
	
	setup do
		#{:ok, "OK"} = RedisSessions.RedixPool.command( ~w(FLUSHDB) )
		:ok
	end
end
