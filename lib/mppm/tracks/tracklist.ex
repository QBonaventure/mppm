defmodule Mppm.Tracklist do
  use GenServer
  use Ecto.Schema
  import Ecto.Query


  @primary_key {:server_id, :id, autogenerate: false}
  schema "tracklists"  do
    belongs_to :server, Mppm.ServerConfig, foreign_key: :id, primary_key: true, define_field: false
    field :tracks_ids, {:array, :integer}, default: []
    field :tracks, {:array, %Mppm.Track{}}, default: [], virtual: true
  end


  # def get(server_login) do
  #   case Mppm.Tracklist.fetch_data(server_login)
  # end

  def fetch_tracks_data(server_login) do
    # q = from tracks in Mppm.Track,
    #   left_join: t in Mppm.Tracklist, on: [tracks],
    #   select: {tracks}
    # # Ecto.Adapters.SQL.query!(
    # #   Mppm.Repo,
    # #   "SELECT tracks.* FROM tracks
    # #   JOIN tracklists t on t.track_id = tracks.id
    # #   JOIN mp_servers_configs sc ON sc.id = t.server_id
    # #   WHERE sc.login = $1
    # #   ORDER BY t.index ASC",
    # #   [server_login]
    # #   )
    # # |> Map.get(:rows)
    # # |> Enum.map(& Ecto.Changeset.change(&1, Mppm.Track) )
    # Mppm.Repo.all(q)
  end


  def add_track(%Mppm.Tracklist{} = tracklist, %Mppm.Track{} = track, index), do:
    %{tracklist | tracks: List.insert_at(tracklist.tracks, index, track)}


  def get_server_tracklist(server_login) do
    tracklist = Mppm.Repo.one(
      from tl in Mppm.Tracklist,
      join: sc in Mppm.ServerConfig, on: tl.server_id == sc.id,
        select: tl,
      where: sc.login == ^server_login
    )

    case tracklist do
      nil ->
        %Mppm.Tracklist{server_id: Mppm.ServerConfig.get_server_id(server_login)}
      %Mppm.Tracklist{} ->
        tracks =
          Mppm.Repo.all(from t in Mppm.Track, where: t.id in ^tracklist.tracks_ids)

        tracks_list =
          tracklist.tracks_ids
          |> Enum.map(fn id -> Enum.find(tracks, & &1.id == id) end)

        Map.put(tracklist, :tracks, tracks_list)
    end

  end


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_init_value) do
    state =
      %{tracklists: []}
    {:ok, state, {:continue, :check_files}}
  end


end
