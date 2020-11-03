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
    {:manialink, [id: "user-best-time", version: 3], [content]}

  def user_best_time(nil), do:
    get_user_best_time_root()
  def user_best_time(time_record), do:
    {
      :frame,
      [pos: "-160 50"],
      [
        {:label, [text: "My Best Time", pos: "10 0", text_size: "2"], []},
        {:label, [text: Mppm.TimeRecord.to_string(time_record.lap_time), textsize: "1", pos: "20 -5"], []}
      ]
    }
    |> get_user_best_time_root()



  def get_local_records_root(content \\ nil), do:
    {:manialink, [id: "local-records", version: 3], [content]}

  def get_table(time_records) do update_table(time_records) end
  def update_table(time_records) do
    times =
      time_records
      |> Enum.sort_by(& &1.lap_time)
      |> Enum.take(10)

    base_content =
      [
        {:label, [text: "Local Records", pos: "10 0", textsize: "2"], []},
        {:quad, [size: "10 60", pos: "20 0", opacity: "1", colorize: "a20000000"], []},
        {:quad, [size: "50 60", opacity: "1", pos: "0 0 1", colorize: "a20000"], []},
      ]
      |> List.insert_at(1, display_lines(times))
      |> List.flatten

    {:frame, [pos: "-160 40", scale: "1.0"], base_content}
    |> get_local_records_root
  end

  def display_lines(times) do
    {
      :frame,
      [id: "records-list", pos: "0 -5"],
      Enum.map_reduce(times, 0, fn time_record, acc ->
        time_record = Mppm.Repo.preload(time_record, :user)
        line =
          {:frame, [id: Integer.to_string(acc), size: "50 50", pos: "2 "<>Integer.to_string(-acc*4)], [
          {:label, [text: Mppm.TimeRecord.to_string(time_record.lap_time), textsize: "1", pos: "30 0"], []},
            {:label, [text: Integer.to_string(acc+1) <> ".", textsize: "1"], []},
            {:label, [text: time_record.user.nickname, textsize: "1", pos: "3 0"], []}
        ]}
        {line, acc+1}
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
