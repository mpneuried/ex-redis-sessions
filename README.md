# RedisSessions

[![Travis Build Status](https://img.shields.io/travis/mpneuried/ex-redis-sessions.svg)](https://travis-ci.org/mpneuried/ex-redis-sessions)
[![Windows Tests](https://img.shields.io/appveyor/ci/mpneuried/ex-redis-sessions.svg?label=WindowsTest)](https://ci.appveyor.com/project/mpneuried/ex-redis-sessions)
[![Coveralls Coverage](https://img.shields.io/coveralls/mpneuried/ex-redis-sessions.svg)](https://coveralls.io/github/mpneuried/ex-redis-sessions)

[![Hex.pm Version](https://img.shields.io/hexpm/v/redis_sessions.svg)](https://hex.pm/packages/redis_sessions)
[![Deps Status](https://beta.hexfaktor.org/badge/all/github/mpneuried/ex-redis-sessions.svg?branch=master)](https://beta.hexfaktor.org/github/mpneuried/ex-redis-sessions)
[![Hex.pm](https://img.shields.io/hexpm/dt/redis_sessions.svg?maxAge=2592000)](https://hex.pm/packages/redis_sessions)

This is a Elixir module to keep sessions in a Redis datastore and add some useful methods.
The main purpose of this module is to generalize sessions across application server platforms.

It's also an elixir port of the node.js module [redis-sessions](https://github.com/smrchy/redis-sessions).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `redis_sessions` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:redis_sessions, "~> 0.1.0"}]
    end
    ```

  2. Ensure `redis_sessions` is started before your application:

    ```elixir
    def application do
      [applications: [:redis_sessions]]
    end
    ```

## Usage

### Basic methods

create a session - [`create/6`](https://hexdocs.pm/redis_sessions/RedisSessions.Client.html#create/6)

```elixir
{ :ok, %{ token: token } } = RedisSessions.Client.create( "appname", "the_users_id", "127.0.0.1" )
```

Get a session - [`get/3`](https://hexdocs.pm/redis_sessions/RedisSessions.Client.html#get/3)

```elixir
session_token = "q3uvHvVqEcnTAaIsWSkgAcvDSKsTyVyameD3s7TjBU1lMVeB3hW7bsgZitfoxqkr"

{:ok, session } = RedisSessions.Client.create( "appname", session_token )
# session ->  %{ id: "the_users_id", r:2, w:1, idle: 3, ttl: 3600, d: nil }
```

Add additional data to the session - [`set/4`](https://hexdocs.pm/redis_sessions/RedisSessions.Client.html#set/4)

```elixir
session_token = "q3uvHvVqEcnTAaIsWSkgAcvDSKsTyVyameD3s7TjBU1lMVeB3hW7bsgZitfoxqkr"
session_data = %{ "my" => "additional", "data" => 2, "save" => "to", "my" => "session" }

{:ok, session } = RedisSessions.Client.set( "appname", session_token, session_data )
# session ->  %{ id: "the_users_id", r:2, w:2, idle: 3, ttl: 3600, ip: "127.0.0.1", d: %{ "my" => "additional", "data" => 2, "save" => "to", "my" => "session" } }
```

Kill a session - [`kill/3`](https://hexdocs.pm/redis_sessions/RedisSessions.Client.html#kill/3)

```elixir
session_token = "q3uvHvVqEcnTAaIsWSkgAcvDSKsTyVyameD3s7TjBU1lMVeB3hW7bsgZitfoxqkr"

{:ok, %{ kill: 1 } } = RedisSessions.Client.kill( "appname", session_token, session_data )
```

### Special user methods

Get all sessions of a user's id - [`soid/3`](https://hexdocs.pm/redis_sessions/RedisSessions.Client.html#soid/3)

```elixir
{:ok, sessions } = RedisSessions.Client.soid( "appname", "the_users_id" )
# sessions ->  [
#   %{ id: "the_users_id", r:2,  w:2,  idle: 3,  ttl: 3600, ip: "127.0.0.1", d: %{ "my" => "additional", "data" => 2, "save" => "to", "my" => "session" } },
#   %{ id: "the_users_id", r:13, w:23, idle: 42, ttl: 3600, ip: "192.168.1.23" }
# ]
```

Kill all sessions of a user's id - [`killsoid/3`](https://hexdocs.pm/redis_sessions/RedisSessions.Client.html#killsoid/3)

```elixir
{:ok, %{ kill: 3 } } = RedisSessions.Client.killsoid( "appname", "the_users_id" )
```

### Special app methods

Get the count of active sessions - [`activity/3`](https://hexdocs.pm/redis_sessions/RedisSessions.Client.html#activity/3)

```elixir
{:ok, %{ activity: 1 } } = RedisSessions.Client.activity( "appname" )
```

Get all sessions of an app - [`soapp/3`](https://hexdocs.pm/redis_sessions/RedisSessions.Client.html#soapp/3)

```elixir
{:ok, sessions } = RedisSessions.Client.soapp( "appname" )
# sessions ->  [
#   %{ id: "the_users_id", r: 2,  w: 2,  idle: 3,   ttl: 3600, ip: "127.0.0.1", d: %{ "my" => "additional", "data" => 2, "save" => "to", "my" => "session" } },
#   %{ id: "the_users_id", r: 13, w: 23, idle: 42,  ttl: 3600, ip: "192.168.1.23" },
#   %{ id: "another_user", r: 1,  w: 42, idle: 666, ttl: 9999, ip: "192.168.1.13" }
# ]
```

Kill all sessions aof an app - [`killall/2`](https://hexdocs.pm/redis_sessions/RedisSessions.Client.html#killall/2)

```elixir
{:ok, %{ kill: 3 } } = RedisSessions.Client.killall( "appname" )
```

## Session Attributes

A Session map will look like:

```elixir
%{ id: "the_users_id", r:2, w:1, idle: 3, ttl: 3600, ip: "127.0.0.1", d: nil }
```

Attributes:

- **`id`** `Binary`: The sessions/users id you defined during the `.create/6` method.
- **`idle`** `Number`: The idle time of this session in seconds
- **`r`** `Number`: The number of reads of this session
- **`w`** `Number`: The number of writes to this session
- **`ttl`** `Number`: The time to live for this session in seconds
- **`ip`** `Binary`: The ip you set during create. Could be used to differ the same user on different devices/platforms.
- **`d`** `Map`: A map of additional data saved to this session


## Release History

|Version|Date|Description|
|:--:|:--:|:--|
|0.1.1|2016-09-28|use regular json encoding without key to atom feature. Added debug infos|
|0.1.0|2016-09-28|Initial finished version|
|0.0.1|2016-09-27|Main calls done|
|0.0.0|2016-09-16|development ...|

## The MIT License (MIT)

Copyright © 2016 M. Peter, http://www.tcs.de

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
