defmodule RedisSessions.ClientTest do
	use ExUnit.Case
	doctest RedisSessions.Client, only: [get: 3]

	@regex_token ~r/^[A-Z0-9]+$/i

	setup do
		{:ok, "OK"} = RedisSessions.RedixPool.command( ~w(FLUSHDB) )
		:ok
	end

	###
	# .create/6
	###

	test ".create" do
		{:ok, %{token: token}} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ foo: "bar", ping: "pong"} )
		assert Regex.match?(@regex_token, token )
	end

	test ".create d: with one nil" do
		{:ok, %{token: token}} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ foo: "bar", ping: nil} )
		assert Regex.match?(@regex_token, token )
		#TODO check ping in d obj
	end
	
	test ".create d: only one nil" do
		{:ok, %{token: token}} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ ping: nil} )
		assert Regex.match?(@regex_token, token )
		#TODO check ping in d obj
	end

	test ".create no d" do
		{:ok, %{token: token}} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600 )
		assert Regex.match?(@regex_token, token )
		#TODO check ping in d obj
	end

	test ".create invalid app" do
		assert RedisSessions.Client.create( "exrs-test??", "foo", "127.0.0.1", 3600, %{ foo: "bar"} ) === {:error, [ {:app, :invalidFormat, "Invalid app format"} ]}
	end

	test ".create d: invalid type" do
		assert RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, "abc" ) === {:error, [ {:d, :invalidValue, "d must be an object"} ]}
	end

	test ".create d: invalid app, id, ip and d" do
		assert RedisSessions.Client.create( "exrs-test??", "??", "127.0.0.1.127.0.0.1.127.0.0.1.127.0.0.1.127.0.0.1.127.0.0.1", 3600, "abc" ) === {:error, [ {:app, :invalidFormat, "Invalid app format"},{:id, :invalidFormat, "Invalid id format"},{:ip, :invalidFormat, "Invalid ip format"},{:d, :invalidValue, "d must be an object"} ]}
	end

	###
	# .get/3
	###
	test ".get" do
		{:ok, %{ token: token }} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ foo: "bar"} )
		{:ok, %{ id: "foo", r: 2, w: 1, idle: idle, ttl: 3600, ip: "127.0.0.1", d: %{foo: "bar"} }} = RedisSessions.Client.get( "exrs-test", token )
		assert idle < 10
	end

	test ".get invalid app" do
		assert RedisSessions.Client.get( "exrs-test??", "O9qFHC1p97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu" ) === {:error, [{:app, :invalidFormat, "Invalid app format"}]}
	end

	test ".get missing app" do
		assert RedisSessions.Client.get( nil, "O9qFHC1p97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu" ) === {:error, [{:app, :missingParameter, "no app supplied"}, {:app, :invalidFormat, "Invalid app format"}]}
	end

	test ".get invalid token content" do
		assert RedisSessions.Client.get( "exrs-test", "???FHC1p97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu" ) === {:error, [{:token, :invalidFormat, "Invalid token format"}]}
	end

	test ".get invalid token length" do
		assert RedisSessions.Client.get( "exrs-test", "97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu" ) === {:error, [{:token, :invalidFormat, "Invalid token format"}]}
	end

	test ".get missing token" do
		assert RedisSessions.Client.get( "exrs-test", nil ) === {:error, [{:token, :missingParameter, "no token supplied"}, {:token, :invalidFormat, "Invalid token format"}]}
	end

end
