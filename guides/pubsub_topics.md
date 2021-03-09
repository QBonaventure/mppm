
# PubSub Topics

\* > server login

## "players-status"

- {:user_connection_to_server, server_login, user_login, is_spectator?}
- {:servers_users_updated, server_login, servers_users}
- {:role_rmoved, , role}
- {:role_granted, , role}

## "maps-status"

- {:loaded_map, server_login, map_uid}
- {:update_server_map, server_login, track_uid}
- {:endmap, server_login, track_uid}
- {:current_track_info, server_login, track_uid}


## "race-status"

- {:player_waypoint, server_login, user_login, waypoint_nb, time}
- {:turn_start, server_login}

## "server-version-status"
- {:new_server_version, server_version_nb}

## "server-status"
- {:starting, server_login}
- {:started, server_login}
- {:start_failed, server_login}
- {:stopping, server_login}
- {:stopped, server_login}
- {:created, Mppm.ServerConfig.t()}
- {:deleted, Mppm.ServerConfig.t()}
- {:updated, Mppm.ServerConfig.t()}

## "server-status:*"
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
- {:version_change, server_version}


## "broker-status:*"

- {:connection_established, socket}


## "ruleset-status"

- {:ruleset_change, server_login, ruleset}
