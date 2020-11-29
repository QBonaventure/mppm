defmodule Mppm.ServerConfig do
  require Logger
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias __MODULE__
  alias Mppm.Repo
  import Record

  defrecord(:xmlElement, extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl"))
  defrecord(:xmlAttribute, extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl"))
  defrecord(:xmlText, extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl"))

  # @app_path Application.get_env(:mppm, :app_path)
  @root_path Application.get_env(:mppm, :game_servers_root_path)
  @config_path @root_path <> "UserData/Config/"
  @maps_path @root_path <> "UserData/Maps/"


  schema "servers_configs" do
    has_one :ruleset, Mppm.GameRules, foreign_key: :server_id, on_replace: :update
    many_to_many :tracks, Mppm.Track, join_through: "tracklists", join_keys: [server_id: :id, track_id: :id]
    field :login, :string
    field :password, :string
    field :name, :string
    field :comment, :string
    field :max_players, :integer, default: 32
    field :player_pwd, :string
    field :spec_pwd, :string
    field :superadmin_pass, :string
    field :admin_pass, :string
    field :user_pass, :string
    field :keep_player_slot, :boolean, default: false
    field :disable_horns, :boolean, default: true
    field :ip_address, EctoNetwork.INET
    field :bind_ip, EctoNetwork.INET
    field :autosave_replays, :boolean, default: false
    field :autosave_validation_replays, :boolean, default: false
    field :client_inputs_max_latency, :integer, default: 250
    field :connection_upload_rate, :integer, default: 500000
    field :connection_download_rate, :integer, default: 500000
    field :packet_assembly_multithread, :boolean, default: true
    field :packets_per_frame, :integer, default: 0
    field :full_packets_per_frame, :integer, default: 10
    field :visuals_delay, :integer, default: 400
    field :trust_client_to_server_sending_rate, :integer, default: 64
    field :visuals_server_to_client_sending_rate, :integer, default: 64
    field :disable_replay_recording, :boolean, default: true
    field :workers_nb, :integer, default: 2
  end

  def get_all() do
    Mppm.Repo.all(Mppm.ServerConfig)
    |> Mppm.Repo.preload(ruleset: [:mode])
  end

  def get_server_id(server_login), do:
    Mppm.Repo.get_by(Mppm.ServerConfig, login: server_login) |> Map.get(:id)

  def get_server_config(server_login) do
    Mppm.Repo.get_by(Mppm.ServerConfig, login: server_login)
    |> Mppm.Repo.preload(ruleset: [:mode, :ta_respawn_behaviour, :rounds_respawn_behaviour])
  end


  @required [:login, :password, :max_players]
  @users_pwd [:superadmin_pass, :admin_pass, :user_pass]
  def create_server_changeset(%ServerConfig{} = server_config \\ %ServerConfig{}, data \\ %{}) do
    data =
      defaults_missing_passwords(data)
      |> Map.put_new("mode_id", 1)

    server_config
    |> cast(data, [
      :login, :password, :name, :comment, :player_pwd, :spec_pwd,
      :max_players, :superadmin_pass, :admin_pass, :user_pass,
      :ip_address, :client_inputs_max_latency, :connection_upload_rate,
      :connection_download_rate, :packet_assembly_multithread, :packets_per_frame,
      :full_packets_per_frame, :visuals_delay, :trust_client_to_server_sending_rate,
      :visuals_server_to_client_sending_rate, :disable_replay_recording, :workers_nb,
      ])
    |> put_assoc(:ruleset, %Mppm.GameRules{mode_id: 1})
    |> validate_required(@required)
  end

  def changeset(%ServerConfig{} = config, params) do
    config
    |> cast(params, [:name, :comment, :player_pwd, :spec_pwd, :max_players, :ip_address,
    :client_inputs_max_latency, :connection_upload_rate,
    :connection_download_rate, :packet_assembly_multithread, :packets_per_frame,
    :full_packets_per_frame, :visuals_delay, :trust_client_to_server_sending_rate,
    :visuals_server_to_client_sending_rate, :disable_replay_recording, :workers_nb,
    ])
    |> cast_assoc(:ruleset)
  end


  def create_new_server(game_server_config) do
    result =
      %ServerConfig{}
      |> ServerConfig.create_server_changeset(game_server_config)
      |> Repo.insert

    case result do
      {:ok, server_config} ->
        tracks = Enum.map(Mppm.Track.get_random_tracks(1), & &1)
        GenServer.cast(Mppm.Tracklist, {:upsert_tracklist, %Mppm.Tracklist{server_id: server_config.id, tracks: tracks}})
        result
      _ -> result
    end
  end


  def update(changeset) do
    case changeset |> Repo.update do
      {:ok, server_config} ->
        server_config = server_config |> Mppm.Repo.preload(:ruleset, force: true)
        create_config_file(server_config)

        if ruleset_changes = Map.get(changeset.changes, :ruleset) do
          propagate_ruleset_changes(server_config, changeset)
          if Map.has_key?(ruleset_changes.changes, :mode_id) do
            Phoenix.PubSub.broadcast(Mppm.PubSub, "ruleset-status", {:ruleset_change, server_config.login, server_config.ruleset})
          end
        end

      {:error, _changeset} ->
        {:ok, nil}
    end
  end


  def propagate_ruleset_changes(%ServerConfig{} = server_config, %Ecto.Changeset{changes: %{ruleset: %Ecto.Changeset{changes: changes}}}) do
    pid = {:global, {:broker_requester, server_config.login}}
    mode_vars =
      GenServer.call({:global, {:game_server, server_config.login}}, :get_current_game_mode_id)
      |> Mppm.GameRules.get_script_variables_by_mode()

    to_update =
      Map.from_struct(server_config.ruleset)
      |> Enum.filter(fn {key, _value} -> Map.has_key?(mode_vars, key) end)

    GenServer.call(pid, {:update_ruleset, to_update})
    if switch_game_mode?(changes) do
      GenServer.call(pid, {:switch_game_mode, Mppm.Repo.get(Mppm.Type.GameMode, changes.mode_id)})
    end

    {:ok, to_update}
  end
  def propagate_ruleset_changes(_pid, _changeset), do: {:no, nil}

  def switch_game_mode?(%{mode_id: _}), do: true
  def switch_game_mode?(_), do: false

  def defaults_missing_passwords(data) do
    Enum.reduce @users_pwd, data, fn field, acc ->
      Map.put_new(acc, to_string(field), generate_random_password(12))
    end
  end


  def generate_random_password(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64 |> binary_part(0, length)
  end


  def create_config_file(%ServerConfig{} = serv_config) do
    source_path = "#{@config_path}dedicated_cfg.default.txt"
    xml = get_default_xml(source_path)

    authorization_levels = {:authorization_levels, [], [
      {:level, [], [
        {:name, [], ['SuperAdmin']},
        {:password, [], [charlist(serv_config.superadmin_pass)]}
      ]},
      {:level, [], [
        {:name, [], ['Admin']},
        {:password, [], [charlist(serv_config.admin_pass)]}
      ]},
      {:level, [], [
        {:name, [], ['User']},
        {:password, [], [charlist(serv_config.user_pass)]}
      ]},
    ]}

    masterserver_account =
      elem(xml, 2)
      |> List.keyfind(:masterserver_account, 0)
      |> elem(2)
      |> List.keyreplace(:password, 0, {:password, [], [charlist(serv_config.password)]})
      |> List.keyreplace(:login, 0, {:login, [], [charlist(serv_config.login)]})
#      |> List.keyreplace(:validation_key, 0, {:validation_key, [], [charlist(Application.get_env(:mppm, :masteraccount_validation_key))]})
    masterserver_account = {:masterserver_account, [], masterserver_account}

    server_options =
      elem(xml, 2)
      |> List.keyfind(:server_options, 0)
      |> elem(2)
      |> List.keyreplace(:name, 0, {:name, [], [charlist(serv_config.name)]})
      |> List.keyreplace(:comment, 0, {:comment, [], [charlist(serv_config.comment)]})
      |> List.keyreplace(:max_players, 0, {:max_players, [], [charlist(serv_config.max_players)]})
      |> List.keyreplace(:password_spectator, 0, {:password_spectator, [], [charlist(serv_config.spec_pwd)]})
      |> List.keyreplace(:password, 0, {:password, [], [charlist(serv_config.player_pwd)]})
      |> List.keyreplace(:disable_horns, 0, {:disable_horns, [], [charlist(serv_config.disable_horns)]})
      |> List.keyreplace(:keep_player_slots, 0, {:keep_player_slots, [], [charlist(serv_config.keep_player_slot)]})
      |> List.keyreplace(:autosave_replays, 0, {:autosave_replays, [], [charlist(serv_config.autosave_replays)]})
      |> List.keyreplace(:autosave_validation_replays, 0, {:autosave_validation_replays, [], [charlist(serv_config.autosave_validation_replays)]})
      |> List.keyreplace(:clientinputs_maxlatency, 0, {:clientinputs_maxlatency, [], [charlist(serv_config.client_inputs_max_latency)]})
    server_options = {:server_options, [], server_options}

    system_config =
      elem(xml, 2)
      |> List.keyfind(:system_config, 0)
      |> elem(2)
      |> List.keyreplace(:force_ip_address, 0, {:force_ip_address, [], [charlist(serv_config.ip_address)]})
      |> List.keyreplace(:connection_uploadrate, 0, {:connection_uploadrate, [], [charlist(serv_config.connection_upload_rate)]})
      |> List.keyreplace(:connection_downloadrate, 0, {:connection_downloadrate, [], [charlist(serv_config.connection_download_rate)]})
      |> List.keyreplace(:workerthreadcount, 0, {:workerthreadcount, [], [charlist(serv_config.workers_nb)]})
      |> List.keyreplace(:packetassembly_multithread, 0, {:packetassembly_multithread, [], [charlist(serv_config.packet_assembly_multithread)]})
      |> List.keyreplace(:packetassembly_packetsperframe, 0, {:packetassembly_packetsperframe, [], [charlist(serv_config.packets_per_frame)]})
      |> List.keyreplace(:packetassembly_fullpacketsperframe, 0, {:packetassembly_fullpacketsperframe, [], [charlist(serv_config.full_packets_per_frame)]})
      |> List.keyreplace(:delayedvisuals_s2c_sendingrate, 0, {:delayedvisuals_s2c_sendingrate, [], [charlist(serv_config.visuals_server_to_client_sending_rate)]})
      |> List.keyreplace(:trustclientsimu_c2s_sendingrate, 0, {:trustclientsimu_c2s_sendingrate, [], [charlist(serv_config.trust_client_to_server_sending_rate)]})
      |> List.keyreplace(:disable_replay_recording, 0, {:disable_replay_recording, [], [charlist(serv_config.disable_replay_recording)]})
    system_config = {:system_config, [], system_config}

    new_xml = {:dedicated, [], [authorization_levels, masterserver_account, server_options, system_config]}

    pp = :xmerl.export_simple([new_xml], :xmerl_xml)
    |> List.flatten

    filename = serv_config.login <> ".txt"

    Logger.info "["<>serv_config.login<>"] Writing new config file"
    :file.write_file(@config_path <> filename, pp)

    filename
  end


  def create_ruleset_file(%ServerConfig{ruleset: %Ecto.Association.NotLoaded{}} = serv_config), do:
    create_ruleset_file(serv_config |> Mppm.Repo.preload(ruleset: [:mode]))
  def create_ruleset_file(%ServerConfig{ruleset: %Mppm.GameRules{mode: %Ecto.Association.NotLoaded{}}} = serv_config), do:
    create_ruleset_file(serv_config |> Mppm.Repo.preload(ruleset: [:mode]))
  def create_ruleset_file(%ServerConfig{} = server_config) do
    target_path = "#{@maps_path}MatchSettings/#{server_config.login}.txt"

    script_settings = {
      :mode_script_settings,
      [],
      Mppm.GameRules.get_script_variables_by_mode(server_config.ruleset.mode)
      |> Enum.map(fn {key, value} ->
        {:setting, [
          name: value,
          type: get_type(Map.get(server_config.ruleset, key)),
          value: script_setting_value_correction(Map.get(server_config.ruleset, key))], []}
      end)
    }

    game_info = {:gameinfos, [], [
      {:game_mode, [], [charlist(0)]},
      {:script_name, [], [charlist(server_config.ruleset.mode.script_name)]}
    ]}

    tracklist =
      case File.exists?(target_path) do
        true ->
          get_default_xml(target_path)
        false ->
          get_default_xml("#{@maps_path}MatchSettings/tracklist.txt")
      end
      |> elem(2)
      |> Enum.filter(fn {v, _, _} -> Enum.member?([:map, :startindex], v) end)

    new_xml =
      {:playlist, [], [game_info, script_settings] ++ tracklist}
      |> List.wrap
      |> :xmerl.export_simple(:xmerl_xml)
      |> List.flatten

    Logger.info "["<>server_config.login<>"] Writing new ruleset"
    :file.write_file(target_path, new_xml)
  end


  def get_tracks_list(server_login) do
    "#{@maps_path}MatchSettings/#{server_login}.txt"
    |> get_default_xml
    |> elem(2)
    |> Enum.filter(fn {key, _attr, _value} -> key == :map end)
    |> Enum.map(fn {:map, _, [{_, _, [track_path]}]} ->
      %Mppm.Track{
        name: clear_filename(track_path)
      }
    end)
  end

  def clear_filename(filename) do
    filename
    |> List.to_string
    |> String.split("/")
    |> List.last
    |> String.split(".")
    |> List.first
  end


  def create_tracklist(%Mppm.ServerConfig{id: id}), do:
    Mppm.Repo.get(Mppm.Tracklist, id) |> create_tracklist()

  def create_tracklist(%Mppm.Tracklist{server: %Ecto.Association.NotLoaded{}} = tracklist), do:
    Mppm.Repo.preload(tracklist, :server) |> create_tracklist()

  def create_tracklist(%Mppm.Tracklist{tracks: []} = tracklist) do
    tracklist
    |> Map.put(:tracks, Mppm.Repo.all(from t in Mppm.Track, where: t.id in ^tracklist.tracks_ids))
    |> create_tracklist()
  end

  def create_tracklist(%Mppm.Tracklist{server: %{login: login}} = tracklist) do
    target_path = "#{@maps_path}MatchSettings/#{login}.txt"

    game_info =
      get_default_xml(target_path)
      |> elem(2)
      |> Enum.filter(& Enum.member?([:gameinfos, :mode_script_settings], elem(&1, 0)))

    tracks =
      tracklist.tracks
      |> Enum.map(& {:map, [], [{:file, [], [charlist(Mppm.TracksFiles.mx_track_path(&1))]}] })
      |> List.insert_at(0, {:startindex, [], [charlist("1")]})

    new_xml = {:playlist, [], game_info ++ tracks}
    pp = :xmerl.export_simple([new_xml], :xmerl_xml) |> List.flatten

    Logger.info "["<>login<>"] Writing new tracklist"
    :file.write_file(target_path, pp)
  end


  defp script_setting_value_correction(true), do: 1
  defp script_setting_value_correction(false), do: 0
  defp script_setting_value_correction(value), do: value


  defp get_type(value) when is_boolean(value), do: "boolean"
  defp get_type(value) when is_integer(value), do: "integer"
  defp get_type(value) when is_binary(value), do: "text"

  defp charlist(value) when is_binary(value), do: String.to_charlist(value)
  defp charlist(value) when is_integer(value), do: Integer.to_string(value) |> String.to_charlist
  defp charlist(%Postgrex.INET{} = value), do: charlist(EctoNetwork.INET.decode(value))
  defp charlist(true), do: ['True']
  defp charlist(false), do: ['False']
  defp charlist(nil = _value), do: []


  def get_default_xml(path) do
    {result, _misc} = path |>:xmerl_scan.file([{:space, :normalize}])
    [clean] = :xmerl_lib.remove_whitespace([result])
    :xmerl_lib.simplify_element(clean)
  end


  def get_available_titlepacks do
    'ls #{@root_path}UserData/Packs/'
    |> :os.cmd
    |> to_string
    |> String.split("\n", trim: true)
    |> Enum.map(fn pack ->
        String.replace_suffix(pack, ".Title.Pack.gbx", "")
      end)
  end

  def get_available_controllers do
    'ls /opt/mppm/'
    |> :os.cmd
    |> to_string
    |> String.split("\n", trim: true)
    |> Enum.filter(fn x -> x != "maniaplanet" end)
  end

end
