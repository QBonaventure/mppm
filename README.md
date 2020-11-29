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

\* > server login

### "players-status"

- {:user_connection_to_server, server_login, user_login, is_spectator?}
- {:servers_users_updated, server_login, servers_users}
- {:role_rmoved, , role}
- {:role_granted, , role}

### "maps-status"

- {:loaded_map, server_login, map_uid}
- {:update_server_map, server_login, track_uid}
- {:endmap, server_login, track_uid}
- {:current_track_info, server_login, track_uid}


### "race-status"

- {:player_waypoint, server_login, user_login, waypoint_nb, time}
- {:turn_start, server_login}


### "server-status:*"

- {:new_chat_message, chat_message}
- {:beginmatch}
- {:endmatch}
- {:beginmap, track_info_map}
- {:endmap}
- {:start_of_match, server_login}
- {:score, server_login}
- {:end_of_game, server_login}
- {:loaded_map, server_login, map_uid}
- {:podium_start, server_login}
- {:podium_end, server_login}
- {:broker_started, state.login}


### "broker-status:*"

- {:connection_established, socket}


### "ruleset-status"

- {:ruleset_change, server_login, ruleset}
