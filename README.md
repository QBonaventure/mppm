# Mppm

Never ask what MPPM means. All you need to know is that once it runs, it allows
you spawning countless Trackmania game servers, easily search and add tracks,
set your game rules, and play! Besides installing MPPM, which is pretty straight
forward, you'd never need to fiddle with the system, but only use the web browser
app to do it all.

It is managing your game server most tedious tasks, and it's also a in-game
controller. Why not use another well established server controller? Well, it was
supposed to, and used to. But it brought its lot of troubles to support at least
the three main ones: it wasn't efficient and more messy for both the development
and the end user. So, it was not planned, but it also packages its own controller.

This brings a few advantages:
- it's the most lightweight solution you could dream of
- if your server starts, so does its controller
- all-in-one solutions, way more simple to use
- it's blazing fast, really real real-time
- it's ubiquitous, your controller is in-game, on your 2nd screen web browser, on your smartphone
- it makes it pretty easy to build up tools for your server, including web tools
- etc.

And now I can bring why it can shine: Elixir. Elixir is a raising language, based
on an industry seasoned platform (Erlang/OTP) and inspired by Ruby for its syntax
and environment, built to process very large amount of messages, concurrently and
failure proof!


## Functionalities

There are 3 main functionalities:
- game servers management (on the web or smartphone)
- in-game controller
- public webpages displaying various info about your server

### Game servers
- download any available dedicated server version
- (un)install dedicated server from filesystem
- let run multiple servers on various dedicated version
- easily switch a game server to a different version
- full configuration of servers through the web app
- full update of game rules through the web app
- easy drag'n'drop of tracks from ManiaExchange results or reordering
- (UPCOMING) export, share and load configuration, rules, white/blacklist presets
- (UPCOMING) build map+rules presets sequences

### In-game UI / Controller
- local records
- replay/restart map
- personal best time
- live race ranking
- checkpoints time delta with best local time
- (UPCOMING) team competition managerment with team logos and player rosters

### Other tools
- web page about the game server
- local records browser

## Dependencies

We may recommend using [asdf](https://github.com/asdf-vm/asdf) to install
dependencies. It allows you to install and manage various versions of most common
runtimes, as well as to pinpoint specific version of it for any paths.

### System
  As of now, the application is strictly developed on CentOS 7. However it should
  work on any Linux distribution.

  - inotify-tools
  - PostgreSQL 10
  - NodeJS 12

### Erlang/Elixir

  - Erlang/OTP 22
  - Elixir 1.10


## Prerequisites

  - [Trackmania OAuth API registration](https://api.trackmania.com/manager)


## Config

After copying the \*.exs.dist files into \*.exs, you can:
- edit the files manually;
- use the `.env` file (copied from `.env.dist`);
- set shell variables

### Using the .env file
You can safely export all the files variables before starting the application using a subshell command, i.e.:
`(export $(grep -v '^#' .env | xargs) && mix phx.server)`


### config.exs
  - secret_key_base: ""
  (generate generate your own key with `mix phx.gen.secret`)
  - signing_salt: ""
  ( generate your own salt with `mix phx.gen.secret 32`)

### (dev|prod).exs

  - url: [host: "example.com", port: 443]
  - redirect_uri: edit the protocol and host pas, i.e. https://example.com/auth/trackmania/callback

### secret.exs

  - Set your PostgreSQL hostname,  username, password and edit the  database name
  if you wish
  - Set your client_id and client_secret for the Trackmania OAuth

###


## First start

### Beforehand

Trackmania servers need ssl certificates to run. On some systems, such as linux 
distributions based on RHEL, the server will be looking for an inexistant file :
`/etc/pki/tls/certs/ca-certificates.crt`. But we do have `ca-bundle.crt`, so simply 
execute `# cp /etc/pki/tls/certs/ca-bundle.crt /etc/pki/tls/certs/ca-certificates.crt`,
and you should be good to go!

### Without docker

  * Go to the application root folder
  * Install elixir dependencies with `mix deps.get` (you may also manually run `mix deps.compile` but that will be done anyway if necessary at start)
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `npm install --prefix assets/`
  * You may need to create the /opt/mppm, and gives right to the user running the application 
  * Finally, start the Phoenix endpoint with `mix phx.server` (or
    `(export $(grep -v '^#' .env | xargs) && mix phx.server)` if you use the env file)

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

### With Docker

A docker-compose.yml file is provided and can be used as such. It makes use of a `.env` file that you can copy from `.env.dist` before editing. `docker-compose up` and you're good to go!


## Elixir / Phoenix resources

  * Elixir doc: https://hexdocs.pm/elixir/Kernel.html
  * Phoenix: https://hexdocs.pm/phoenix
  * Phoenix PubSub: https://hexdocs.pm/phoenix_pubsub
  * Phoenix LiveView: https://hexdocs.pm/phoenix_live_view
  * Source: https://github.com/phoenixframework/phoenix
