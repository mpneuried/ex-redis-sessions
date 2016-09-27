defmodule RedisSessions.ClientTest do
	use ExUnit.Case
	doctest RedisSessions.Client, only: [kill: 3, activity: 3]

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
		assert idle < 100
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
		{:ok, %{ kill: 1}} = RedisSessions.Client.kill( "exrs-test", token )
		{:ok, nil} = RedisSessions.Client.get( "exrs-test", token )
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
	
	###
	# soapp/3
	###
	test ".soapp/3" do
		{:ok, _} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600 )
		{:ok, _} = RedisSessions.Client.create( "exrs-test", "bar", "127.0.0.1", 3600 )
		{:ok, %{ sessions: sessions } } = RedisSessions.Client.soapp( "exrs-test" )
		
		# check for the expected session types
		for session <- sessions do
			:ok = case session do
				%{ id: "foo", r: 1, w: 1, idle: _, ttl: 3600, ip: "127.0.0.1", d: nil } -> :ok
				%{ id: "bar", r: 1, w: 1, idle: _, ttl: 3600, ip: "127.0.0.1", d: nil } -> :ok
				_ -> session
			end
		end
	end
	
	test ".soapp/3 with wait timeout dt" do
		{:ok, _} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600 )
		IO.inspect "Wait for 12 sec. to check .soapp/3 timeout"
		:timer.sleep(12000)
		{:ok, _} = RedisSessions.Client.create( "exrs-test", "bar", "127.0.0.1", 3600 )
		{:ok, _} = RedisSessions.Client.create( "exrs-test", "buzz", "127.0.0.1", 3600 )
		{:ok, %{ sessions: sessions } } = RedisSessions.Client.soapp( "exrs-test", 11 )
		
		# check for the expected session types
		for session <- sessions do
			:ok = case session do
				%{ id: "buzz", r: 1, w: 1, idle: _, ttl: 3600, ip: "127.0.0.1", d: nil } -> :ok
				%{ id: "bar", r: 1, w: 1, idle: _, ttl: 3600, ip: "127.0.0.1", d: nil } -> :ok
				_ -> session
			end
		end
	end
	
	test ".soapp/3 unkown app" do
		assert RedisSessions.Client.soapp( "exrs-test-unkown", 300 ) === {:ok, %{ sessions: [] } } 
	end
	
	test ".soapp/3 invalid app" do
		assert RedisSessions.Client.soapp( "exrs-test??" ) === {:error, [{:app, :invalidFormat, "Invalid app format"}]}
	end

	test ".soapp/3 missing app" do
		assert RedisSessions.Client.soapp( nil ) === {:error, [{:app, :missingParameter, "no app supplied"}, {:app, :invalidFormat, "Invalid app format"}]}
	end
	
	test ".soapp/3 invalid dt type" do
		assert RedisSessions.Client.soapp( "exrs-test", "foo" ) === {:error, [{:dt, :invalidValue, "ttl must be a positive integer >= 10"}]}
	end
	
	test ".soapp/3 invalid dt value" do
		assert RedisSessions.Client.soapp( "exrs-test", 1 ) === {:error, [{:dt, :invalidValue, "ttl must be a positive integer >= 10"}]}
	end
	
	###
	# soid/3
	###
	test ".soid/3" do
		{:ok, _} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600 )
		{:ok, _} = RedisSessions.Client.create( "exrs-test", "foo", "192.168.1.1", 3600 )
		{:ok, _} = RedisSessions.Client.create( "exrs-test", "buzz", "127.0.0.1", 3600 )
		{:ok, %{ sessions: sessions } } = RedisSessions.Client.soid( "exrs-test", "foo" )
		
		# check for the expected session types
		for session <- sessions do
			:ok = case session do
				%{ id: "foo", r: 1, w: 1, idle: _, ttl: 3600, ip: "127.0.0.1", d: nil } -> :ok
				%{ id: "foo", r: 1, w: 1, idle: _, ttl: 3600, ip: "192.168.1.1", d: nil } -> :ok
				_ -> session
			end
		end
	end
	
	test ".soid/3 empty" do
		assert RedisSessions.Client.soid( "exrs-test", "unkown" ) === {:ok, %{ sessions: [] } }
	end

	test ".soid/3 invalid app" do
		assert RedisSessions.Client.soid( "exrs-test??", "foo" ) === {:error, [{:app, :invalidFormat, "Invalid app format"}]}
	end

	test ".soid/3 missing app" do
		assert RedisSessions.Client.soid( nil, "foo" ) === {:error, [{:app, :missingParameter, "no app supplied"}, {:app, :invalidFormat, "Invalid app format"}]}
	end
	
	test ".soid/3 invalid id type" do
		assert RedisSessions.Client.soid( "exrs-test", "123?" ) === {:error, [{:id, :invalidFormat, "Invalid id format"}]}
	end
	
	###
	# soid/3
	###
	test ".killsoid/3" do
		{:ok, %{ token: tokenA }} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600 )
		{:ok, %{ token: tokenB }} = RedisSessions.Client.create( "exrs-test", "foo", "192.168.1.1", 3600 )
		{:ok, %{ token: tokenC }} = RedisSessions.Client.create( "exrs-test", "buzz", "127.0.0.1", 3600 )
		
		assert RedisSessions.Client.killsoid( "exrs-test", "foo" ) === {:ok, %{kill: 2} }
		assert RedisSessions.Client.soid( "exrs-test", "foo" ) === {:ok, %{ sessions: [] } }
		assert RedisSessions.Client.get( "exrs-test", tokenA ) === {:ok, nil}
		assert RedisSessions.Client.get( "exrs-test", tokenB ) === {:ok, nil}
		{:ok, %{ id: "buzz", r: 2, w: 1, idle: _, ttl: 3600, ip: "127.0.0.1", d: nil }} = RedisSessions.Client.get( "exrs-test", tokenC )
	end
	
	test ".killsoid/3 empty" do
		assert RedisSessions.Client.killsoid( "exrs-test", "unkown" ) === {:ok, %{ kill: 0 } }
	end

	test ".killsoid/3 invalid app" do
		assert RedisSessions.Client.killsoid( "exrs-test??", "foo" ) === {:error, [{:app, :invalidFormat, "Invalid app format"}]}
	end

	test ".killsoid/3 missing app" do
		assert RedisSessions.Client.killsoid( nil, "foo" ) === {:error, [{:app, :missingParameter, "no app supplied"}, {:app, :invalidFormat, "Invalid app format"}]}
	end
	
	test ".killsoid/3 invalid id type" do
		assert RedisSessions.Client.killsoid( "exrs-test", "123?" ) === {:error, [{:id, :invalidFormat, "Invalid id format"}]}
	end
	
	
	###
	# killall/2
	###
	test ".killall/2" do
		{:ok, %{ token: tokenA }} = RedisSessions.Client.create( "exrs-test", "foo", "127.0.0.1", 3600 )
		{:ok, %{ token: tokenB }} = RedisSessions.Client.create( "exrs-test", "foo", "192.168.1.1", 3600 )
		{:ok, %{ token: tokenC }} = RedisSessions.Client.create( "exrs-test", "buzz", "127.0.0.1", 3600 )
		
		assert RedisSessions.Client.killall( "exrs-test" ) === {:ok, %{kill: 3} }
		assert RedisSessions.Client.get( "exrs-test", tokenA ) === {:ok, nil}
		assert RedisSessions.Client.get( "exrs-test", tokenB ) === {:ok, nil}
		assert RedisSessions.Client.get( "exrs-test", tokenC ) === {:ok, nil}
	end
	
	test ".killall/2 empty" do
		assert RedisSessions.Client.killall( "exrs-test-unkown" ) === {:ok, %{ kill: 0 } }
	end

	test ".killall/2 invalid app" do
		assert RedisSessions.Client.killall( "exrs-test??" ) === {:error, [{:app, :invalidFormat, "Invalid app format"}]}
	end

	test ".killall/2 missing app" do
		assert RedisSessions.Client.killall( nil ) === {:error, [{:app, :missingParameter, "no app supplied"}, {:app, :invalidFormat, "Invalid app format"}]}
	end


end
