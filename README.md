# Mppm

## Dependencies

We may recommend using [asdf](https://github.com/asdf-vm/asdf) to install
dependencies. It allows you to install and manage various versions of most common
runtimes, as well as to pinpoint specific version of it for any paths.

### System
  As of now, the application is strictly developed on CentOS 7. However it should
  work on any Linux distribution.

  - inotify-tools
  - PostgreSQL 10
  - NodeJS 6.4

### Erlang/Elixir

  - Erlang/OTP 22
  - Elixir 1.9.4


## Prerequisites

  - [Trackmania OAuth API registration](https://api.trackmania.com/manager)


## Config

  After copying the \*.exs.dist files into \*.dist, make the following changes:

### config.exs
  - secret_key_base: ""
  (generate generate your own key with `mix phx.gen.secret`)
  - signing_salt: ""
  ( generate your own salt with `mix phx.gen.secret 32`)

### (dev|prod).exs

  - url: [host: "example.com", port: 80]
  - redirect_uri: "your_registered_callback_uri_for_Trackmania_OAuth"

### (dev|prod).secret.exs

  - Set your PostgreSQL hostname,  username, password and edit the  database name
  if you wish
  - Set your client_id and client_secret for the Trackmania OAuth


## First start

  * Go to the application root folder
  * Install elixir dependencies with `mix deps.get` (you may also manually run `mix deps.compile` but that will be done anyway if necessary at start)
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `npm install --prefix assets/`
  * Finally, start the Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.


## Elixir / Phoenix resources

  * Elixir doc: https://hexdocs.pm/elixir/Kernel.html
  * Phoenix: https://hexdocs.pm/phoenix
  * Phoenix PubSub: https://hexdocs.pm/phoenix_pubsub
  * Phoenix LiveView: https://hexdocs.pm/phoenix_live_view
  * Source: https://github.com/phoenixframework/phoenix
