defmodule Mppm.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      app: :mppm,
      version: @version,
      description: description(),
      docs: docs(),
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      package: package(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Mppm.Application, []},
      extra_applications: [:logger, :runtime_tools, :logger_file_backend, :os_mon]
    ]
  end

  defp description(), do:
    """
    Game server manager and controller for Trackmania
    """

  defp package(), do: [
    files: ["lib", "docs", "mix.exs", "README.md", "LICENSE.md"],
    maintainers: ["Quentin Bonaventure"],
    licenses: ["MIT"],
    links: %{"GitHub" => "https://github.com/QBonaventure/mppm"}
  ]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ecto_network, "~> 1.3.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:phoenix, "~> 1.5"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.1"},
      {:httpoison, "~> 1.7"},
      {:joken, "~> 2.0"},
      {:logger_file_backend, "~> 0.0.11"},
      {:oauth2, "~> 2.0"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.13"},
      {:phoenix_live_dashboard, "~> 0.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.14"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:xmlrpc, "~> 1.4"},
      {:observer_cli, "~> 1.5"},
      {:slugify, "~> 1.3"}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end


  defp docs do
    [
      source_ref: "v#{@version}",
      main: "overview",
      logo: "ftc.svg",
      extra_section: "GUIDES",
      assets: "guides/assets",
      formatters: ["html"],
      groups_for_modules: groups_for_modules(),
      extras: extras(),
      groups_for_extras: groups_for_extras()
    ]
  end

  defp extras() do
    [
      "guides/broker/broker_receiver.md",
      "guides/pubsub_topics.md"
    ]
  end

  defp groups_for_extras do
    [
      "Broker": ~r/guides\/broker\/.?/,
      "PubSub Topics": ~r/guides\/pubsub_topics.md/,
    ]
  end

  defp groups_for_modules() do
    [
      "In-game UI modules": [
        Mppm.GameUI.BasicInfo,
        Mppm.GameUI.LiveRaceRanking,
        Mppm.GameUI.TimePartialsDelta,
        Mppm.GameUI.TimeRecords,
      ],
      "XML-RPC Broker": [
        Mppm.Broker.Receiver,
        Mppm.Broker.Requester,
        Mppm.Broker.MethodResponse,
        Mppm.Broker.MethodCall
      ],
    ]
  end

end
