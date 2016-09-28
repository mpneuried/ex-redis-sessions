use Mix.Config

config :logger, level: :info

config :redis_sessions,
	# redis sessions namespace
	ns: "rs",
	# redis sessions wipe timeout. it set to `0` automatic wipeing will be disabled
	wipe: 600,
	# redis connection string
	redis: "redis://localhost:6379/3",
	# redix/poolboy pool size
	pool_size: 1,
	# redix/poolboy pool overflow
	pool_overflow: 0
