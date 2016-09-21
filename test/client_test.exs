defmodule RedisSessions.ClientTest do
	use ExUnit.Case
	doctest RedisSessions.Client, only: [kill: 3]

	@regex_token ~r/^[A-Z0-9]+$/i

	setup do
		{:ok, "OK"} = RedisSessions.RedixPool.command( ~w(FLUSHDB) )
		:ok
	end

	###
	# .create/6
	###

	test ".create/6" do
		{:ok, %{token: token}} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ foo: "bar", ping: "pong"} )
		assert Regex.match?(@regex_token, token )
	end

	test ".create/6 d: with one nil" do
		{:ok, %{token: token}} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ foo: "bar", ping: nil} )
		assert Regex.match?(@regex_token, token )
		#TODO check ping in d obj
	end
	
	test ".create/6 d: only one nil" do
		{:ok, %{token: token}} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ ping: nil} )
		assert Regex.match?(@regex_token, token )
		#TODO check ping in d obj
	end

	test ".create/6 no d" do
		{:ok, %{token: token}} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600 )
		assert Regex.match?(@regex_token, token )
		#TODO check ping in d obj
	end

	test ".create/6 invalid app" do
		assert RedisSessions.Client.create( "exrs-test??", "foo", "127.0.0.1", 3600, %{ foo: "bar"} ) === {:error, [ {:app, :invalidFormat, "Invalid app format"} ]}
	end

	test ".create/6 d: invalid type" do
		assert RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, "abc" ) === {:error, [ {:d, :invalidValue, "d must be an object"} ]}
	end

	test ".create/6 d: invalid app, id, ip and d" do
		assert RedisSessions.Client.create( "exrs-test??", "??", "127.0.0.1.127.0.0.1.127.0.0.1.127.0.0.1.127.0.0.1.127.0.0.1", 3600, "abc" ) === {:error, [ {:app, :invalidFormat, "Invalid app format"},{:id, :invalidFormat, "Invalid id format"},{:ip, :invalidFormat, "Invalid ip format"},{:d, :invalidValue, "d must be an object"} ]}
	end

	###
	# .get/3
	###
	test ".get/3" do
		{:ok, %{ token: token }} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ foo: "bar"} )
		{:ok, %{ id: "foo", r: 2, w: 1, idle: idle, ttl: 3600, ip: "127.0.0.1", d: %{foo: "bar"} }} = RedisSessions.Client.get( "exrs-test", token )
		assert idle < 10
	end

	test ".get/3 invalid app" do
		assert RedisSessions.Client.get( "exrs-test??", "O9qFHC1p97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu" ) === {:error, [{:app, :invalidFormat, "Invalid app format"}]}
	end

	test ".get/3 missing app" do
		assert RedisSessions.Client.get( nil, "O9qFHC1p97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu" ) === {:error, [{:app, :missingParameter, "no app supplied"}, {:app, :invalidFormat, "Invalid app format"}]}
	end

	test ".get/3 invalid token content" do
		assert RedisSessions.Client.get( "exrs-test", "???FHC1p97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu" ) === {:error, [{:token, :invalidFormat, "Invalid token format"}]}
	end

	test ".get/3 invalid token length" do
		assert RedisSessions.Client.get( "exrs-test", "97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu" ) === {:error, [{:token, :invalidFormat, "Invalid token format"}]}
	end

	test ".get/3 missing token" do
		assert RedisSessions.Client.get( "exrs-test", nil ) === {:error, [{:token, :missingParameter, "no token supplied"}, {:token, :invalidFormat, "Invalid token format"}]}
	end
	
	###
	# .set/4
	###
	test ".set/4 " do
		{:ok, %{ token: token }} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ foo: "bar"} )
		{:ok, %{ id: "foo", r: 2, w: 1, idle: _, ttl: 3600, ip: "127.0.0.1", d: %{foo: "bar"} }} = RedisSessions.Client.get( "exrs-test", token )
		{:ok, %{ id: "foo", r: 2, w: 2, idle: _, ttl: 3600, ip: "127.0.0.1", d: %{foo: "buzz"} }} = RedisSessions.Client.set( "exrs-test", token, %{foo: "buzz"} )
		{:ok, %{ id: "foo", r: 3, w: 2, idle: _, ttl: 3600, ip: "127.0.0.1", d: %{foo: "buzz"} }} = RedisSessions.Client.get( "exrs-test", token )
	end
	
	test ".set/4  with a key to nil" do
		{:ok, %{ token: token }} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ foo: "bar", fizz: 42} )
		{:ok, %{ id: "foo", r: 2, w: 1, idle: _, ttl: 3600, ip: "127.0.0.1", d: %{foo: "bar", fizz: 42} }} = RedisSessions.Client.get( "exrs-test", token )
		{:ok, %{ id: "foo", r: 2, w: 2, idle: _, ttl: 3600, ip: "127.0.0.1", d: %{foo: 23} }} = RedisSessions.Client.set( "exrs-test", token, %{foo: 23, fizz: nil} )
		{:ok, %{ id: "foo", r: 3, w: 2, idle: _, ttl: 3600, ip: "127.0.0.1", d: %{foo: 23} }} = RedisSessions.Client.get( "exrs-test", token )
	end
	
	test ".set/4  just add a key and remove one" do
		{:ok, %{ token: token }} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ foo: "bar", fizz: 42} )
		{:ok, %{ id: "foo", r: 2, w: 1, idle: _, ttl: 3600, ip: "127.0.0.1", d: %{foo: "bar", fizz: 42} }} = RedisSessions.Client.get( "exrs-test", token )
		{:ok, %{ id: "foo", r: 2, w: 2, idle: _, ttl: 3600, ip: "127.0.0.1", d: %{foo: "bar", bar: "foo"} }} = RedisSessions.Client.set( "exrs-test", token, %{bar: "foo", fizz: nil} )
		{:ok, %{ id: "foo", r: 3, w: 2, idle: _, ttl: 3600, ip: "127.0.0.1", d: %{foo: "bar", bar: "foo"} }} = RedisSessions.Client.get( "exrs-test", token )
	end
	
	test ".set/4  set the only key nil" do
		{:ok, %{ token: token }} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ foo: "bar"} )
		{:ok, %{ id: "foo", r: 2, w: 1, idle: _, ttl: 3600, ip: "127.0.0.1", d: %{foo: "bar"} }} = RedisSessions.Client.get( "exrs-test", token )
		{:ok, %{ id: "foo", r: 2, w: 2, idle: _, ttl: 3600, ip: "127.0.0.1", d: nil }} = RedisSessions.Client.set( "exrs-test", token, %{foo: nil} )
		{:ok, %{ id: "foo", r: 3, w: 2, idle: _, ttl: 3600, ip: "127.0.0.1", d: nil }} = RedisSessions.Client.get( "exrs-test", token )
	end
	
	test ".set/4  clear data" do
		{:ok, %{ token: token }} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ foo: "bar", fizz: 42} )
		{:ok, %{ id: "foo", r: 2, w: 1, idle: _, ttl: 3600, ip: "127.0.0.1", d: %{foo: "bar", fizz: 42} }} = RedisSessions.Client.get( "exrs-test", token )
		{:ok, %{ id: "foo", r: 2, w: 2, idle: _, ttl: 3600, ip: "127.0.0.1", d: nil }} = RedisSessions.Client.set( "exrs-test", token, nil )
		{:ok, %{ id: "foo", r: 3, w: 2, idle: _, ttl: 3600, ip: "127.0.0.1", d: nil }} = RedisSessions.Client.get( "exrs-test", token )
	end
	
	test ".set/4  invalid app" do
		assert RedisSessions.Client.set( "exrs-test??", "O9qFHC1p97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu", %{ foo: "bar" } ) === {:error, [{:app, :invalidFormat, "Invalid app format"}]}
	end
	
	test ".set/4  missing app" do
		assert RedisSessions.Client.set( nil, "O9qFHC1p97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu", %{ foo: "bar" } ) === {:error, [{:app, :missingParameter, "no app supplied"}, {:app, :invalidFormat, "Invalid app format"}]}
	end
	
	test ".set/4  invalid token content" do
		assert RedisSessions.Client.set( "exrs-test", "???FHC1p97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu", %{ foo: "bar" } ) === {:error, [{:token, :invalidFormat, "Invalid token format"}]}
	end
	
	test ".set/4  invalid token length" do
		assert RedisSessions.Client.set( "exrs-test", "97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu", %{ foo: "bar" } ) === {:error, [{:token, :invalidFormat, "Invalid token format"}]}
	end
	
	test ".set/4  missing token" do
		assert RedisSessions.Client.set( "exrs-test", nil, %{ foo: "bar" } ) === {:error, [{:token, :missingParameter, "no token supplied"}, {:token, :invalidFormat, "Invalid token format"}]}
	end
	
	###
	# .kill/3
	###
	test ".kill/3" do
		{:ok, %{ token: token }} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600, %{ foo: "bar"} )
		{:ok, %{ id: "foo", r: 2, w: 1, idle: _, ttl: 3600, ip: "127.0.0.1", d: %{foo: "bar"} }} = RedisSessions.Client.get( "exrs-test", token )
		res = RedisSessions.Client.kill( "exrs-test", token )
		IO.inspect res
		{:ok, %{ kill: 1}} = res
		IO.inspect RedisSessions.Client.get( "exrs-test", token )
	end

	test ".kill/3 invalid app" do
		assert RedisSessions.Client.kill( "exrs-test??", "O9qFHC1p97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu" ) === {:error, [{:app, :invalidFormat, "Invalid app format"}]}
	end

	test ".kill/3 missing app" do
		assert RedisSessions.Client.kill( nil, "O9qFHC1p97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu" ) === {:error, [{:app, :missingParameter, "no app supplied"}, {:app, :invalidFormat, "Invalid app format"}]}
	end

	test ".kill/3 invalid token content" do
		assert RedisSessions.Client.kill( "exrs-test", "???FHC1p97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu" ) === {:error, [{:token, :invalidFormat, "Invalid token format"}]}
	end

	test ".kill/3 invalid token length" do
		assert RedisSessions.Client.kill( "exrs-test", "97WpDMePPom5brodlnWKVn2jUMv55POqfkAAnJVseAbvGdgZitb6b7eu" ) === {:error, [{:token, :invalidFormat, "Invalid token format"}]}
	end

	test ".kill/3 missing token" do
		assert RedisSessions.Client.kill( "exrs-test", nil ) === {:error, [{:token, :missingParameter, "no token supplied"}, {:token, :invalidFormat, "Invalid token format"}]}
	end

end
