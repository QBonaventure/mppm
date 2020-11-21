use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :mppm, MppmWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]


config :oauth2, debug: true

config :mppm, Mppm.Service.Trackmania,
  redirect_uri: "http://192.168.1.90:4000/auth/trackmania/callback",
  authorize_url: "https://api.trackmania.com/oauth/authorize",
  token_url: "https://api.trackmania.com/api/access_token",
  site: "https://trackmania.com",
  response_type: "code"


# Watch static and templates for browser reloading.
config :mppm, MppmWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/mppm_web_ui_web/{live,views}/.*(ex)$",
      ~r"lib/mppm_web_ui_web/templates/.*(eex)$",
      ~r{lib/my_app_web/live/.*(ex)$}
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console,
  level: :debug,
  format: "[$level] $message\n"


# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime


import_config "dev.secret.exs"
