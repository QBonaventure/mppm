defmodule Mppm.Notifications do
  use GenServer


  def get_actives() do
    Mppm.Repo.all(Mppm.Note)
  end

  def notify(type, msg) do
    datetime =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
    note = Mppm.Note.new(type, msg, datetime)

    GenServer.cast(Mppm.Notifications, {:new_notification, note})
  end

  def handle_cast({:new_notification, %Mppm.Note{} = note}, state) do
    Mppm.Note.insert(note)
    Phoenix.PubSub.broadcast(Mppm.PubSub, "notifications", {:new_notification, note})
    {:noreply, state}
  end


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_), do: {:ok, %{}}

end
