defmodule Mppm.GameUI.TimeRecords do
  use GenServer
  alias Mppm.TimeTracker
  import Ecto.Query


  def handle_info({:new_time_record, server_login, time}, state) do
    records = GenServer.call(Mppm.TimeTracker, {:get_server_records, server_login})

    records
    |> get_table()
    |> Mppm.GameUI.Helper.send_to_all(server_login)

    time = Mppm.Repo.preload(time, :user)
    time
    |> user_best_time
    |> Mppm.GameUI.Helper.send_to_user(server_login, time.user.login)

    {:noreply, state}
  end

  def handle_info({:beginmap, server_login, _}, state) do
    records = GenServer.call(Mppm.TimeTracker, {:get_server_records, server_login})

    records
    |> get_table()
    |> Mppm.GameUI.Helper.send_to_all(server_login)

    Mppm.ConnectedUsers.get_connected_users(server_login)
    |> Enum.each(fn user ->
      Enum.find(records, & &1.user_id == user.id)
      |> user_best_time()
      |> Mppm.GameUI.Helper.send_to_user(server_login, user.login)
    end)

    {:noreply, state}
  end
  #
  def handle_info(_, state), do: {:noreply, state}



  def get_user_best_time_root(content \\ nil), do:
    {:manialink, [id: "user-best-time", version: 3], [Mppm.GameUI.Stylesheet.get_stylesheet(), content]}

  def user_best_time(nil), do:
    get_user_best_time_root()
  def user_best_time(time_record), do:
    {
      :frame,
      [pos: "-160 40", scale: "1"],
      [
        {:label, [text: "My Best Time", class: "header-text", pos: "10 0"], []},
        {:label, [text: Mppm.TimeRecord.to_string(time_record.lap_time), class: "text", pos: "20 -5"], []},
        {:quad, [size: "35 9", pos: "1 1", class: "background-quad"], []}
      ]
    }
    |> get_user_best_time_root()



  def get_local_records_root(content \\ nil), do:
    {:manialink, [id: "local-records", version: 3], [Mppm.GameUI.Stylesheet.get_stylesheet(), content]}

  def get_table(time_records) do update_table(time_records) end
  def update_table(time_records) do
    times =
      time_records
      |> Enum.sort_by(& &1.lap_time)
      |> Enum.take(10)

    quad_size = "35 "<> Integer.to_string(3*Enum.count(times)+6)

    base_content =
      [
        {:label, [text: "Local Records", pos: "10 0", class: "header-text"], []},
        {:quad, [size: quad_size, pos: "1 1", class: "background-quad"], []}
      ]
      |> List.insert_at(1, display_lines(times))
      |> List.flatten

    {:frame, [pos: "-160 30"], base_content}
    |> get_local_records_root
  end

  def display_lines(times) do
    {
      :frame,
      [id: "records-list", pos: "0 -5"],
      Enum.map_reduce(times, 0, fn time_record, index ->
        time_record = Mppm.Repo.preload(time_record, :user)
        line =
          {:frame, [id: Integer.to_string(index), size: "50 50", pos: "2 "<>Integer.to_string(-index*4)], [
            # {:label, [text: Integer.to_string(acc+1) <> "888.", class: "text", pos: "5 0", halign: "right"], []},
              {:label, [text: Integer.to_string(index+1)<>".", class: "text", pos: "6 0", halign: "right"], []},
            {:label, [text: time_record.user.nickname, class: "text", pos: "7 0", halign: "left"], []},
            {:label, [text: Mppm.TimeRecord.to_string(time_record.lap_time), class: "text", pos: "33 0", halign: "right"], []}
            # {:label, [text: "sssssssssss", class: "text", pos: "33 0", halign: "right"], []}
        ]}
        {line, index+1}
      end)
      |> elem(0)
    }
  end



  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "records-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "time-status")
    {:ok, %{}}
  end

end
