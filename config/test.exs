use Mix.Config

config :logger, level: :debug

config :redis_sessions,
	adapter: RedisSessions.Adapters.Redis,
	redis: "redis://localhost:6379/3",
	pool_size: 1,
	pool_overflow: 0
