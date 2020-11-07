# Mppm

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: http://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix

## Game server message broker

A broker is made up of one supervisor (Mppm.Broker.Supervisor) and two GenServers:
- Mppm.Broker.ReceiverServer
- Mppm.Broker.RequesterServer

The Supervisor is started after game server launch, once it opened its ports. The
ReceiverServer then opens the connection and provides a call method so that the
RequesterServer can retrieve the open port. Everything's stopped on server shutdown.

This design choice hase been made to allow either the receiving or requesting part
of the broker to be able to independently fail without impeding its counterpart.



## PubSub Topics

### "maps-update"
