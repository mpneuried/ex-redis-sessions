defmodule RedisSessions.Mixfile do
	use Mix.Project

	defp package do
		[
			files: ["lib", "mix.exs", "README.md", "LICENSE"],
			maintainers: ["M. Peter"],
			licenses: ["MIT"],
			links: %{"GitHub" => "https://github.com/mpneuried/ex-redis-sessions"}
		]
	end
	
	defp description do
		"""
		An advanced session store for Elixir and NodeJS based on Redis
		"""
	end
	
	def project do
		[
			app: :redis_sessions,
			version: "0.1.3",
			elixir: "~> 1.3",
			build_embedded: Mix.env == :prod,
			start_permanent: Mix.env == :prod,
			deps: deps,
			package: package,
			description: description,
			docs: [ extras: ["README.md"], main: "readme"],
			test_coverage: [tool: ExCoveralls]
		]
	end

	# Configuration for the OTP application
	#
	# Type "mix help compile.app" for more information
	def application do
		[
			mod: {RedisSessions, []},
			applications: [:logger]
		]
	end

	# Dependencies can be Hex packages:
	#
	#	 {:mydep, "~> 0.3.0"}
	#
	# Or git/path repositories:
	#
	#	 {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
	#
	# Type "mix help deps" for more examples and options
	defp deps do
		[
			{:redix, ">= 0.0.0"},
			{:poolboy, "~> 1.4"},
			{:poison, "~> 1.5 or ~> 2.0"},
			{:vex, "~> 0.5"},
			{:dialyze, "~> 0.2", only: :dev},
			{:earmark, ">= 0.0.0", only: [:docs, :dev]},
			{:ex_doc, ">= 0.0.0", only: [:docs, :dev]},
			{:credo, "~> 0.4", only: [:dev, :test]},
			{:excoveralls, "~> 0.4", only: [:dev, :test]}
		]
	end
end
