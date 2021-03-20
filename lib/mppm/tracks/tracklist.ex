defmodule Mppm.Tracklist do
  @moduledoc """
  GenServer taking care of servers tracklists. Also implements convenient functions
  about tracklist
  """
  use GenServer
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  require Logger

  @maps_path Application.get_env(:mppm, :game_servers_root_path) <> "UserData/Maps/"


  @primary_key {:server_id, :id, autogenerate: false}
  schema "tracklists"  do
    belongs_to :server, Mppm.GameServer.Server, foreign_key: :server_id, primary_key: true, define_field: false
    field :tracks_ids, {:array, :integer}, default: []
    field :tracks, {:array, :map}, default: [], virtual: true
  end

  @type t() :: %Mppm.Tracklist{
    server: Mppm.GameServer.Server.t(),
    tracks_ids: [track_id()],
    tracks: [track()]
  }
  @type track_id() :: integer()
  @type track :: Mppm.Track.t()

  def changeset(%Mppm.Tracklist{} = tracklist, params \\ %{}) do
    tracks_ids = Enum.map(params["tracks"], & &1.id)
    params = Map.put(params, "tracks_ids", tracks_ids)
    tracklist
    |> cast(params, [:tracks_ids, :server_id, :tracks])
    |> cast_assoc(:server)
  end

  @spec get_tracklist(Mppm.GameServer.Server.t() | String.t()) :: t()

  def get_tracklist(server_login) when is_binary(server_login) do
    GenServer.call(__MODULE__, {:get_server_tracklist, server_login})
  end

  @doc """
  Persist a tracklist in DB, both insert or update.
  """
  def upsert_tracklist(%Mppm.Tracklist{} = tracklist, changes) do
    {:ok, updated_tracklist} = GenServer.call(__MODULE__, {:update_tracklist, tracklist, changes})
    {:ok, updated_tracklist}
  end


  @doc """
    Adds a track to the tracklist. Downloads it if it doesn't exist yet.

    Returns: {:ok, tracklist} on success.
  """
  @spec add_track(t(), track(), integer()) :: {:ok, t()}
  def add_track(%Mppm.Tracklist{server: %Ecto.Association.NotLoaded{}} = tracklist, track, index),
    do: tracklist |> Mppm.Repo.preload(:server) |> add_track(track, index)
  def add_track(%Mppm.Tracklist{} = tracklist, %Mppm.Track{} = track, index) do
    case Enum.any?(tracklist.tracks, & &1.uuid == track.uuid) do
      true ->
        {:none, tracklist}
      false ->
        GenServer.call(__MODULE__, {:add_track, tracklist, track, index})
    end
  end



  @doc """
    Removes a track from the tracklist.
  """
  def remove_track(%Mppm.Tracklist{server: %Ecto.Association.NotLoaded{}} = tracklist, track_id),
    do: tracklist |> Mppm.Repo.preload(:server) |> remove_track(track_id)
  def remove_track(%Mppm.Tracklist{} = tracklist, track_id) when is_integer(track_id) do
    GenServer.call(__MODULE__, {:remove_track, tracklist, track_id})
  end

  def move_track_to(tracklist, track_id, index) do
    tracks_ids =
      tracklist.tracks_ids
      |> Enum.reject(& &1 == track_id)
      |> List.insert_at(index, track_id)
    GenServer.call(__MODULE__, {:update, tracklist, %{tracks_ids: tracks_ids}})
  end


  def reindex_for_next_track(%Mppm.Tracklist{} = tracklist, track_id) do
    [curr_track_id | tracks_ids] = Map.get(tracklist, :tracks_ids)
    next_track_index = Enum.find_index(tracklist.tracks_ids, & &1 == track_id)
    {to_last, to_first} = Enum.split(tracks_ids, next_track_index-1)
    tracks_ids = [curr_track_id] ++ to_first ++ to_last
    GenServer.call(__MODULE__, {:update, tracklist, %{tracks_ids: tracks_ids}})
  end


  def create_tracklist(%Mppm.GameServer.Server{id: id}),
    do: Mppm.Tracklist |> Mppm.Repo.get(id) |> Mppm.Repo.preload(:server) |> create_tracklist()
  def create_tracklist(%Mppm.Tracklist{server: %Ecto.Association.NotLoaded{}} = tracklist),
    do: tracklist |> Mppm.Repo.preload(:server) |> create_tracklist()
  def create_tracklist(%Mppm.Tracklist{tracks: []} = tracklist) do
    tracklist
    |> Map.put(:tracks, Mppm.Repo.all(from t in Mppm.Track, where: t.id in ^tracklist.tracks_ids))
    |> create_tracklist()
  end
  def create_tracklist(%Mppm.Tracklist{server: %{login: login}} = tracklist) do
    target_path = "#{@maps_path}MatchSettings/#{login}.txt"

    game_info =
      target_path
      |> Mppm.XML.from_file()
      |> elem(2)
      |> Enum.filter(& Enum.member?([:gameinfos, :mode_script_settings], elem(&1, 0)))

    tracks =
      tracklist.tracks
      |> Enum.map(& {:map, [], [{:file, [], [Mppm.XML.charlist(Mppm.TracksFiles.mx_track_path(&1))]}] })
      |> List.insert_at(0, {:startindex, [], [Mppm.XML.charlist("1")]})

    new_xml = {:playlist, [], game_info ++ tracks}
    new_xml = :xmerl.export_simple([new_xml], :xmerl_xml) |> List.flatten

    Logger.info "["<>login<>"] Writing new tracklist"
    :ok = :file.write_file(target_path, new_xml)

    {:ok, target_path}
  end


  def get_server_current_track(server_login) do
    {:ok, tracklist} = GenServer.call(__MODULE__, {:get_server_tracklist, server_login})
    {:ok, Map.get(tracklist, :tracks) |> List.first()}
  end


  def get_server_next_track(server_login) do
    {:ok, tracklist} = GenServer.call(__MODULE__, {:get_server_tracklist, server_login})
    tracks = Map.get(tracklist, :tracks)
    {:ok, Enum.at(tracks, 1, List.first(tracks))}
  end


  ##############################################################################
  ############################# GenServerCallbacks #############################
  ##############################################################################

  def handle_call({:get_server_tracklist, server_login}, _from, state) do
    {:reply, {:ok, Map.get(state, server_login)}, state}
  end

  def handle_call({:update, tracklist, changes}, _from, state) do
    {:ok, updated_tracklist} = upsert(tracklist, changes)
    {:reply, {:ok, updated_tracklist}, %{state | updated_tracklist.server.login => updated_tracklist}}
  end

  def handle_call({:add_track, tracklist, track, index}, _from, state) do
    tracks_ids = List.insert_at(tracklist.tracks_ids, index, track.id)
    tracklist = Map.put(tracklist, :tracks, tracklist.tracks++[track])
    {:ok, updated_tracklist} = upsert(tracklist, %{tracks_ids: tracks_ids})
    {:reply, {:ok, updated_tracklist}, %{state | tracklist.server.login => updated_tracklist}}
  end

  def handle_call({:remove_track, tracklist, track_id}, _from, state) do
    tracks_ids = Enum.reject(tracklist.tracks_ids, & &1 == track_id)
    tracks = Enum.reject(tracklist.tracks, & &1.id == track_id)

    {:ok, updated_tracklist} = upsert(tracklist, %{tracks_ids: tracks_ids})
    {:reply, {:ok, updated_tracklist}, %{state | tracklist.server.login => updated_tracklist}}
  end


  def handle_info({message, server_login, uuid} = msg, state)
  when message in [:current_track, :loaded_map] do
    tracklist = Map.get(state, server_login)
    case length(tracklist.tracks_ids) == 1 do
      true ->
        {:noreply, state}
      false ->
        current_track_index = Enum.find_index(tracklist.tracks, & &1.uuid == uuid)
        {to_last, to_first} = Enum.split(tracklist.tracks_ids, current_track_index)
        {:ok, updated_tracklist} = upsert(tracklist, %{tracks_ids: to_first ++ to_last})
        {:noreply, %{state | server_login => updated_tracklist}}
    end
  end

  def handle_info({:created, %Mppm.GameServer.Server{} = server}, state) do
    tracklist = Mppm.Repo.get(Mppm.Tracklist, server.id)
    tracklist = Map.put(tracklist, :tracks, fetch_tracklist_maps(tracklist))
    {:noreply, Map.put(state, server.login, tracklist)}
  end

  def handle_info({:deleted, server}, state), do:
    {:noreply, Map.delete(state, server.login)}

  def handle_info(_unhandled_message, state) do
    {:noreply, state}
  end


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_init_value) do
    Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    Phoenix.PubSub.subscribe(Mppm.PubSub, "server-status")
    state = fetch_all_tracklists()
    {:ok, state}
  end


  ##############################################################################
  ############################# Private Functions ##############################
  ##############################################################################


  defp upsert(%Mppm.Tracklist{server: %Ecto.Association.NotLoaded{}} = tracklist, changes),
    do: tracklist |> Mppm.Repo.preload(:server) |> upsert(changes)
  defp upsert(tracklist, changes) do
    {:ok, tracklist} =
      Ecto.Changeset.change(tracklist, changes)
      |> Mppm.Repo.update()
    tracklist = sort_tracks(tracklist)
    create_tracklist(tracklist)
    Mppm.PubSub.broadcast("tracklist-status", {:tracklist_update, tracklist.server.login, tracklist})
    {:ok, tracklist}
  end


  defp fetch_all_tracklists() do
    Mppm.Repo.all(
      from tl in Mppm.Tracklist,
      join: sc in Mppm.GameServer.Server, on: tl.server_id == sc.id,
      select: {sc.login, tl})
    |> Enum.map(fn {server_login, tracklist} ->
      {server_login, Map.put(
        tracklist,
        :tracks,
        fetch_tracklist_maps(tracklist)
      )}
    end)
    |> Map.new
  end

  defp fetch_tracklist_maps(%Mppm.Tracklist{} = tracklist) do
    Mppm.Repo.all(
      from t in Mppm.Track,
      where: t.id == fragment("ANY(?)", ^tracklist.tracks_ids),
      order_by: fragment("array_position(?, ?)", ^tracklist.tracks_ids, t.id),
      preload: [:author, :style, :tags]
    )
  end

  def sort_tracks(%Mppm.Tracklist{} = tracklist) do
    tracks = Enum.map(tracklist.tracks, & {&1.id, &1}) |> Map.new()
    sorted_tracks = Enum.map(tracklist.tracks_ids, & Map.get(tracks, &1))
    Map.put(tracklist, :tracks, sorted_tracks)
  end

end
