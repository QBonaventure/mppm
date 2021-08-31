defmodule Mppm.GameUI.TimeRecords do
  use GenServer
  import Ecto.Query

  @behaviour Mppm.GameUI.Module

  @max_local_records_nb 10


  def name, do: "TimeRecords"


  def handle_info({:new_time_record, server_login, time}, state) do
    time = Mppm.Repo.preload(time, :user)
    records =
      Mppm.TimeTracker.get_server_records(server_login)
      |> Enum.sort_by(& &1.lap_time)

    send_records_table(server_login, records)

    time
    |> user_best_time
    |> Mppm.GameUI.Helper.send_to_user(server_login, time.user.login)

    {:noreply, %{state | records: records}}
  end

  def handle_info({:loaded_map, server_login, map_id}, state) do
    records = get_records(state.server_login)
    send_records_table(server_login, records)
    Mppm.ConnectedUsers.get_connected_users(state.server_login)
    |> Enum.each(&send_personal_best(server_login, &1, records))

    {:noreply, %{state | records: records}}
  end

  def handle_info({:user_connected, server_login, user}, state) do
    send_records_table(server_login, state.records)
    send_personal_best(server_login, user, state.records)
    Mppm.GameUI.Helper.toggle_base_ui(state.server_login, "Race_Record", false)
    {:noreply, state}
  end


  def handle_info(reason, state) do
    {:noreply, state}
  end


  def handle_call({:get_best_time, _server_login}, _from, state) do
    {:reply, state.records |> List.first(), state}
  end


  def get_user_best_time_root(content \\ nil), do:
    {:manialink, [id: "user-best-time", version: 3], [Mppm.GameUI.Stylesheet.get_stylesheet(), content]}


  def get_local_records_root(content \\ nil), do:
    {:manialink, [id: "local-records", version: 3], [Mppm.GameUI.Stylesheet.get_stylesheet(), content]}


  def get_table(time_records) do
    base_content =
      [
        {:label, [text: "Local Records", class: "header-text"], []},
        {:quad, [size: "36 4.5", pos: "1 1", class: "background-quad"], []}
      ]
      |> List.insert_at(1, display_lines(time_records))
      |> List.flatten

    {:frame, [pos: "-160 30"], base_content}
    |> get_local_records_root
  end


  def display_lines(times) when length(times) > @max_local_records_nb, do:
    times |> Enum.slice(0, @max_local_records_nb) |> display_lines()

  def display_lines(times) do
    times = Enum.sort_by(times, & &1.lap_time)

    {
      :frame,
      [id: "records-list", pos: "0 -3.6"],
      Enum.map_reduce(times, 0, fn time_record, index ->
        time_record = Mppm.Repo.preload(time_record, :user)
        line =
          {:frame, [id: Integer.to_string(index), size: "50 50", pos: "0 "<>Float.to_string(-index*3.5)], [
            {:label, [text: Integer.to_string(index+1)<>".", class: "text", pos: "6 -0.7", halign: "right"], []},
            {:label, [text: time_record.user.nickname, class: "text", pos: "7 -0.7", halign: "left"], []},
            {:label, [text: Mppm.TimeRecord.to_string(time_record.lap_time), class: "text", pos: "33 -0.7", halign: "right"], []},
            {:quad, [size: "36 4.5", pos: "1 1", class: "background-quad-black"], []}
        ]}
        {line, index+1}
      end)
      |> elem(0)
    }
  end


  def child_spec([server_login]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[server_login]]},
      restart: :transient
    }
  end
  def start_link([server_login]),
    do: GenServer.start_link(__MODULE__, [server_login], name: {:global, {__MODULE__, server_login}})

  def init([server_login]) do
    Process.flag(:trap_exit, true)
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "race-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "server-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "players-status")
    {:ok, %{server_login: server_login, records: []}, {:continue, :init_continue}}
  end

  def handle_continue(:init_continue, state) do
    records = get_records(state.server_login)
    send_records_table(state.server_login, records)
    Mppm.ConnectedUsers.get_connected_users(state.server_login)
    |> Enum.each(& send_personal_best(state.server_login, &1, records))
    Mppm.GameUI.Helper.toggle_base_ui(state.server_login, "Race_Record", false)
    {:noreply, %{state | records: records}}
  end


  def terminate(_reason, state) do
    Mppm.GameUI.Helper.send_to_all(get_local_records_root(), state.server_login)
    Mppm.GameUI.Helper.send_to_all(get_user_best_time_root(), state.server_login)
    Mppm.GameUI.Helper.log_module_stop(state.server_login, name())
    Mppm.GameUI.Helper.toggle_base_ui(state.server_login, "Race_Record", true)
    :normal
  end


  ##############################################################################
  ############################# PRIVATE FUNCTIONS ##############################
  ##############################################################################


  defp send_records_table(server_login, records) do
    records
    |> get_table()
    |> Mppm.GameUI.Helper.send_to_all(server_login)
  end


  defp send_personal_best(server_login, user, records) do
    Enum.find(records, & &1.user_id == user.id)
    |> user_best_time()
    |> Mppm.GameUI.Helper.send_to_user(server_login, user.login)
  end


  defp get_records(server_login) do
    {:ok, track} = Mppm.Tracklist.get_server_current_track(server_login)

    res = Mppm.Repo.all(
      from r in Mppm.TimeRecord,
      join: t in assoc(r, :track),
      where: t.uuid == ^track.uuid,
      order_by: {:desc, r.race_time}
    )
    case res do
      nil -> :none
      records ->
        records |> Enum.sort_by(& &1.lap_time)
    end
  end

  defp user_best_time(nil), do:
    get_user_best_time_root()
  defp user_best_time(%Mppm.TimeRecord{user: %Ecto.Association.NotLoaded{}} = time_record), do:
    time_record |> Mppm.Repo.preload(:user, force: true) |> user_best_time()
  defp user_best_time(time_record) do
    {
      :frame,
      [pos: "-160 40", scale: "1"],
      [
        {:label, [text: "My Best Time", class: "header-text"], []},
        {:label, [text: Mppm.TimeRecord.to_string(time_record.lap_time), class: "text", pos: "20 -5", halign: "center"], []},
        {:quad, [size: "36 4.5", pos: "1 1", class: "background-quad"], []},
        {:quad, [size: "36 4.5", pos: "1 -3.5", class: "background-quad-black"], []}
      ]
    }
    |> get_user_best_time_root()
  end


end
