defmodule Mppm.GameUI.BasicInfo do
  use GenServer

  @behaviour Mppm.GameUI.Module

  def name(), do: "BasicInfo"


  def root_wrap(content \\ nil), do:
    {:manialink, [id: "basic-infos", version: 3], [Mppm.GameUI.Stylesheet.get_stylesheet(), content]}


  def get_info(server_login, %Mppm.User{} = user) do
    get_server_tracks(server_login)
    |> current_track()
    |> add_controls(user)
    |> root_wrap()
  end


  defp current_track({track_one, track_two}) do
    {:frame, [id: "maps", pos: "-160 90"], [
      {:frame, [id: "current-map"], [
        {:label, [class: "text", pos: "1.5 -1", size: "36 3.2", text: track_text(track_one)], []},
        {:quad, [class: "background-quad", pos: "0.5 -0.5", size: "36 3.2"], []},
      ]},
      {:frame, [id: "next-map", pos: "0 -3.7"], [
        {:label, [class: "text", pos: "1.5 -1", size: "36 3.2", text: track_text(track_two), opacity: "0.5"], []},
        {:quad, [class: "background-quad", pos: "0.5 -0.5", size: "36 3.2", opacity: "0.1"], []},
      ]}
    ]}
  end


  def add_controls(manialink, %Mppm.User{roles: %Ecto.Association.NotLoaded{}} = user), do:
    add_controls(manialink, user |> Mppm.Repo.preload([roles: [:user_role]]))
  def add_controls(manialink, %Mppm.User{} = user) do
    case Enum.any?(user.roles, & &1.user_role.name == "Member") do
      false ->
        manialink
      true ->
        cur_track = manialink |> elem(2) |> Enum.at(0)
        next_track = manialink |> elem(2) |> Enum.at(1)

        cur_track = :erlang.setelement(3, cur_track, [replay_button()] ++ elem(cur_track, 2))
        next_track = :erlang.setelement(3, next_track, [skip_button()] ++ elem(next_track, 2))
        :erlang.setelement(3, manialink, [cur_track, next_track])
    end
  end

  defp replay_button(), do: {:label, [text: "replay", action: "restart-map", class: "text", pos: "42 -1"], []}
  defp skip_button(), do: {:label, [text: "skip", action: "skip-map", class: "text", pos: "42 -1"], []}


  defp track_text(%Mppm.Track{author: %Ecto.Association.NotLoaded{}} = track), do:
    track |> Mppm.Repo.preload(:author) |> track_text()
  defp track_text(%Mppm.Track{author: %Mppm.User{nickname: author_name}, name: map_name}), do:
    map_name<>" by "<>author_name

  defp get_server_tracks(server_login) do
    {:ok, current_track} = Mppm.Tracklist.get_server_current_track(server_login)
    {:ok, next_track} = Mppm.Tracklist.get_server_next_track(server_login)
    {current_track, next_track}
  end


  ##############################################################################
  ############################ GenServer Callbacks #############################
  ##############################################################################

  def handle_info({:tracklist_update, _, tracklist}, state) do
    tracklist = tracklist |> Mppm.Repo.preload(:server)
    Mppm.ConnectedUsers.get_connected_users(tracklist.server.login)
    |> Enum.each(& get_info(tracklist.server.login, &1)
    |> Mppm.GameUI.Helper.send_to_user(tracklist.server.login, &1.login))

    {:noreply, state}
  end


  def handle_info({:loaded_map, server_login, _map_uid}, state) do
    Mppm.ConnectedUsers.get_connected_users(server_login)
    |> Enum.each(& get_info(server_login, &1)
    |> Mppm.GameUI.Helper.send_to_user(server_login, &1.login))

    {:noreply, state}
  end

  def handle_info({message, user, _role}, state)
  when message in [:role_removed, :role_granted] do
    if server_login = Mppm.ConnectedUsers.where_is_user(user.login) do
      get_info(server_login, user)
      |> Mppm.GameUI.Helper.send_to_user(server_login, user.login)
    end
    {:noreply, state}
  end

  def handle_info({:servers_users_updated, _server_login, servers_users}, state) do
    Enum.each(servers_users, fn {server_login, users} ->
      Enum.each(users, & get_info(server_login, &1) |> Mppm.GameUI.Helper.send_to_user(server_login, &1.login))
    end)
    {:noreply, state}
  end

  def handle_info(_unhandled_message, state) do
    {:noreply, state}
  end



  ##############################################################################
  ############################## GenServer Impl. ###############################
  ##############################################################################

  def child_spec([server_login]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[server_login]]},
      restart: :transient
    }
  end

  def start_link([server_login], _opts \\ []),
    do: GenServer.start_link(__MODULE__, [server_login], name: {:global, {__MODULE__, server_login}})

  def init([server_login]) do
    Process.flag(:trap_exit, true)
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "tracklist-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "players-status")

    Mppm.GameUI.Helper.log_module_start(server_login, name())

    {:ok, %{server_login: server_login}, {:continue, :init_continue}}
  end

  def handle_continue(:init_continue, state) do
    Mppm.ConnectedUsers.get_connected_users(state.server_login)
    |> Enum.each(& get_info(state.server_login, &1)
    |> Mppm.GameUI.Helper.send_to_user(state.server_login, &1.login))
    Mppm.GameUI.Helper.toggle_base_ui(state.server_login, "Race_Record", false)
    Mppm.GameUI.Helper.reposition_base_ui(state.server_login, "Race_Countdown", {-92, 88.5})
    Mppm.GameUI.Helper.scale_base_ui(state.server_login, "Race_Countdown", 0.65)
    {:noreply, state}
  end

  def terminate(_reason, state) do
    Mppm.GameUI.Helper.send_to_all(root_wrap(), state.server_login)
    Mppm.GameUI.Helper.log_module_stop(state.server_login, name())
    Mppm.GameUI.Helper.reset_base_ui(state.server_login, ["Race_Countdown", "Race_Record"])
    :normal
  end


end
