# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :phoenix,
  template_engines: [leex: Phoenix.LiveView.Engine]

config :mppm,
  ecto_repos: [Mppm.Repo]

# Configures the endpoint
config :mppm, MppmWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "afV0CREl4daxWFaO0yEaAUaIVD8Fa6hutve1ayPU5SmrCdjbfVo5BAQhzje0TFUw",
  render_errors: [view: MppmWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Mppm.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [
    signing_salt: "PT9C+Rx6EMTp2/HqPQaZwCUVkJkfX9lp"
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason


config :mppm,
  app_path: File.cwd!,
  mp_servers_root_path: "/opt/mppm/TrackmaniaServer/"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
