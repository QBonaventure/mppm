
# PubSub Topics

\* > server login

## "user-status"

- {:app_role_updated, user, role}


## "players-status"

- {:user_connection, server_login, user_login, is_spectator?}
- {:user_disconnection, server_login, user_login, reason}

- {:user_info, server_login, user_login, user_nickname, is_spectator?}
- {:users_info_list, server_login, users_info_list}

- {:user_connected, server_login, Mppm.User.t()}
Sent by Mppm.ConnectedUsers for other processes to use.
- {:user_disconnected, server_login, Mppm.User.t()}

- {:user_connection_to_server, server_login, user_login, is_spectator?}
- {:servers_users_updated, server_login, servers_users}
- {:role_removed, , role}
- {:role_granted, , role}

## "maps-status"

- {:loaded_map, server_login, map_uid}
- {:update_server_map, server_login, track_uid}
- {:endmap, server_login, track_uid}
- {:current_track_info, server_login, track_uid}
- {:new_track_vote, server_login, %Mppm.TrackKarma{}}


## "race-status"

- {:player_start, server_login, user_login}
- {:player_waypoint, server_login, user_login, waypoint_nb, time}
- {:player_end_lap, server_login, user_login, waypoint_nb, time}
- {:player_end_race, server_login, user_login, waypoint_nb, time}
- {:player_giveup, server_login, user_login}
- {:player_respawn, server_login, user_login}
- {:turn_start, server_login}
- {:new_race_record, server_login, %Mppm.TimeRecord.t()}

## "server-version-status"
- {:new_server_version, server_version_nb}

## "server-status"
- {:starting, server_login}
- {:started, server_login}
- {:start_failed, server_login}
- {:stopping, server_login}
- {:stopped, server_login}
- {:created, Mppm.GameServer.Server.t()}
- {:deleted, Mppm.GameServer.Server.t()}
- {:updated, Mppm.GameServer.Server.t()}
- {:new_chat_message, chat_message}
- {:beginmatch, server_login}
- {:endmatch, server_login}
- {:beginmap, server_login, track_info_map}
- {:endmap, server_login}
- {:start_of_match, server_login}
- {:score, server_login}
- {:end_of_game, server_login}
- {:loaded_map, server_login, map_uid}
- {:podium_start, server_login}
- {:podium_end, server_login}
- {:broker_started, state.login}


## "broker-status:*"

- {:connection_established, socket}


## "ruleset-status"

- {:ruleset_change, server_login, ruleset}
