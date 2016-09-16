# RedisSessions

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
