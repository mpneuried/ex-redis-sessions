# RedisSessions

[![Travis Build Status](https://img.shields.io/travis/mpneuried/ex-redis-sessions.svg)](https://travis-ci.org/mpneuried/ex-redis-sessions)
[![Coveralls Coverage](https://img.shields.io/coveralls/mpneuried/ex-redis-sessions.svg)](https://coveralls.io/github/mpneuried/ex-redis-sessions)
[![Hex.pm Version](https://img.shields.io/hexpm/v/exq.svg)](https://hex.pm/packages/redis_sessions)
[![Deps Status](https://beta.hexfaktor.org/badge/all/github/mpneuried/ex-redis-sessions.svg?branch=master)](https://beta.hexfaktor.org/github/mpneuried/ex-redis-sessions)


This is a Elixir module to keep sessions in a Redis datastore and add some useful methods.
The main purpose of this module is to generalize sessions across application server platforms.

It's also an elixir port of the node.js module [redis-sessions](https://github.com/smrchy/redis-sessions).


## 🚧 Currently work in progress

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
