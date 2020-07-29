defmodule Mppm.Tracklist do
  use GenServer
  use Ecto.Schema

  @primary_key {:server_id, :id, autogenerate: false}
  embedded_schema  do
    belongs_to :server, Mppm.ServerConfig, foreign_key: :id, primary_key: true, define_field: false
    field :list, {:array, Mppm.Track}

  end


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_init_value) do
    state =
      %{tracklists: []}
    {:ok, state, {:continue, :check_files}}
  end


end
