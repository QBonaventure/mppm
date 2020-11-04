defmodule Mppm.Tracklist do
  use GenServer
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset




  @primary_key {:server_id, :id, autogenerate: false}
  schema "tracklists"  do
    belongs_to :server, Mppm.ServerConfig, foreign_key: :server_id, primary_key: true, define_field: false
    field :tracks_ids, {:array, :integer}, default: []
    field :tracks, {:array, %Mppm.Track{}}, default: [], virtual: true
  end


  def changeset(%Mppm.Tracklist{} = tracklist, params \\ %{} ) do
    tracklist
    |> cast(params, [:tracks_ids, :server_id, :tracks])
    |> cast_assoc(:server)
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


  def upsert_tracklist(%Mppm.Tracklist{} = tracklist) do
    mx_tracks_ids = Enum.map(tracklist.tracks, & Map.get(&1, :mx_track_id))
    tracks = Mppm.Repo.all(from t in Mppm.Track, where: t.mx_track_id in ^mx_tracks_ids)

    mxds =
      mx_tracks_ids
      |> Enum.map(fn mx_id ->
        Enum.find(tracks, mx_id, fn track_struct -> track_struct.mx_track_id == mx_id end)
      end)
      |> Enum.map(fn track ->
        case track do
          %Mppm.Track{} ->
            track
          mx_id when is_integer(mx_id) ->
            Mppm.TracksFiles.download_mx_track(Enum.find(tracklist.tracks, & &1.mx_track_id == mx_id))
        end
      end)
      |> Enum.map(& &1.id)

    {:ok, tracklist} =
      %{tracklist | tracks_ids: mxds}
      |> Mppm.Repo.preload(:server)
      |> Mppm.Repo.insert(on_conflict: [set: [tracks_ids: mxds]], conflict_target: :server_id)

    Phoenix.PubSub.broadcast(Mppm.PubSub, "tracklist-state", {:tracklist_update, tracklist})
    Mppm.ServerConfig.create_tracklist(tracklist)
    tracklist
  end


  def add_track(%Mppm.Tracklist{} = tracklist, %Mppm.Track{} = track, index) do
    case File.exists?(Mppm.TracksFiles.mx_track_path(track)) do
      false -> Mppm.TracksFiles.download_mx_track(track)
      _ -> nil
    end
    %{tracklist | tracks: List.insert_at(tracklist.tracks, index, track)}
  end

  def remove_track(%Mppm.Tracklist{} = tracklist, track_id) when is_integer(track_id) do
    %{tracklist | tracks: Enum.reject(tracklist.tracks, & &1.id == track_id)}
  end


  def load_ordered_tracks(%Mppm.Tracklist{tracks_ids: []} = tracklist), do: tracklist
  def load_ordered_tracks(%Mppm.Tracklist{tracks_ids: tracks_ids} = tracklist) do
    Map.put(tracklist, :tracks, from(t in Mppm.Track,
      where: t.id in ^tracks_ids,
      order_by: fragment("array_position(?,?)", ^tracks_ids, t.id)
      )
      |> Mppm.Repo.all
    )
  end

  def get_server_tracklist(server_login) do
    tracklist =
      Mppm.Repo.one(
        from tl in Mppm.Tracklist,
          join: sc in Mppm.ServerConfig, on: tl.server_id == sc.id,
          where: sc.login == ^server_login
    )


    case tracklist do
      %Mppm.Tracklist{} -> tracklist |> load_ordered_tracks()
      _ -> %Mppm.Tracklist{server_id: Mppm.ServerConfig.get_server_id(server_login)}
    end

  end


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_init_value) do
    state =
      %{tracklists: []}
    {:ok, state, {:continue, :check_files}}
  end


end
