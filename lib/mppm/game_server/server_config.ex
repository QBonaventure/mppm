defmodule Mppm.ServerConfig do
  require Logger
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias __MODULE__
  alias Mppm.Repo
  import Record
  alias Mppm.GameServer.{DedicatedServer,Server}

  defrecord(:xmlElement, extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl"))
  defrecord(:xmlAttribute, extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl"))
  defrecord(:xmlText, extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl"))

  # @app_path Application.get_env(:mppm, :app_path)
  @root_path Application.get_env(:mppm, :game_servers_root_path)
  @config_path @root_path <> "UserData/Config/"
  @maps_path @root_path <> "UserData/Maps/"


  @primary_key {:server_id, :id, autogenerate: false}
  schema "servers_configs" do
    belongs_to :server, Mppm.GameServer.Server, primary_key: true, define_field: false
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




  def changeset(%ServerConfig{} = config, data \\ %{}) do
    data =
      data
      |> defaults_missing_passwords()
    config
    |> cast(data, [
      :player_pwd, :spec_pwd, :superadmin_pass, :admin_pass, :user_pass,
      :max_players, :ip_address, :client_inputs_max_latency, :connection_upload_rate,
      :connection_download_rate, :packet_assembly_multithread, :packets_per_frame,
      :full_packets_per_frame, :visuals_delay, :trust_client_to_server_sending_rate,
      :visuals_server_to_client_sending_rate, :disable_replay_recording, :workers_nb
    ])
    |> validate_required([:superadmin_pass])
  end


  @required [:max_players]
  @users_pwd [:superadmin_pass, :admin_pass, :user_pass]
  def new_config(data \\ %{}) do
    data =
      defaults_missing_passwords(data)
      |> Map.put_new("mode_id", 1)

    %Mppm.ServerConfig{}
    |> cast(data, [
      :player_pwd, :spec_pwd,
      :max_players, :superadmin_pass, :admin_pass, :user_pass,
      :ip_address, :client_inputs_max_latency, :connection_upload_rate,
      :connection_download_rate, :packet_assembly_multithread, :packets_per_frame,
      :full_packets_per_frame, :visuals_delay, :trust_client_to_server_sending_rate,
      :visuals_server_to_client_sending_rate, :disable_replay_recording, :workers_nb
      ])
    |> validate_required(@required)
  end


  @required [:max_players]
  @users_pwd [:superadmin_pass, :admin_pass, :user_pass]
  def create_server_changeset(data \\ %{}), do:
    create_server_changeset(%ServerConfig{}, data)
  def create_server_changeset(%ServerConfig{} = server_config, data) do
    data = defaults_missing_passwords(data)

    server_config
    |> cast(data, [
      :player_pwd, :spec_pwd, :max_players, :superadmin_pass, :admin_pass,
      :user_pass, :ip_address, :client_inputs_max_latency, :connection_upload_rate,
      :connection_download_rate, :packet_assembly_multithread, :packets_per_frame,
      :full_packets_per_frame, :visuals_delay, :trust_client_to_server_sending_rate,
      :visuals_server_to_client_sending_rate, :disable_replay_recording, :workers_nb,
      ])
    |> validate_required(@required)
  end


  # def insert(changeset)
  # when changeset.data =  do
  #   case Repo.insert(changeset)
  #   |> ServerConfig.create_server_changeset(game_server_config)
  #   |>
  #
  #   # case result do
  #   #   {:ok, server_config} ->
  #   #     tracks =
  #   #     GenServer.call(Mppm.Tracklist, {:upsert_tracklist, %Mppm.Tracklist{server_id: server_config.id, tracks: tracks}})
  #   #     result
  #   #   _ -> result
  #   # end
  # end


#   def update(changeset) do
#     case changeset |> Repo.update do
#       {:ok, server_config} ->
#         server_config = server_config |> Mppm.Repo.preload(:ruleset, force: true)
#         create_config_file(server_config)
#
#         if ruleset_changes = Map.get(changeset.changes, :ruleset) do
#           propagate_ruleset_changes(server_config, changeset)
#           if Map.has_key?(ruleset_changes.changes, :mode_id) do
#             Phoenix.PubSub.broadcast(Mppm.PubSub, "ruleset-status", {:ruleset_change, server_config.login, server_config.ruleset})
#           end
#         end
#
#       {:error, _changeset} ->
#         {:ok, nil}
#     end
#   end

#

  def create_config_file(%Server{config: %Ecto.Association.NotLoaded{}} = server),
    do: server |> Mppm.Repo.preload(:config) |> create_config_file()
  def create_config_file(%Server{config: %__MODULE{} = config} = server) do
    source_path = "#{@config_path}dedicated_cfg.default.txt"
    xml = Mppm.XML.from_file(source_path)

    authorization_levels = {:authorization_levels, [], [
      {:level, [], [
        {:name, [], ['SuperAdmin']},
        {:password, [], [Mppm.XML.charlist(config.superadmin_pass)]}
      ]},
      {:level, [], [
        {:name, [], ['Admin']},
        {:password, [], [Mppm.XML.charlist(config.admin_pass)]}
      ]},
      {:level, [], [
        {:name, [], ['User']},
        {:password, [], [Mppm.XML.charlist(config.user_pass)]}
      ]},
    ]}

    masterserver_account =
      elem(xml, 2)
      |> List.keyfind(:masterserver_account, 0)
      |> elem(2)
      |> List.keyreplace(:password, 0, {:password, [], [Mppm.XML.charlist(server.password)]})
      |> List.keyreplace(:login, 0, {:login, [], [Mppm.XML.charlist(server.login)]})
    masterserver_account = {:masterserver_account, [], masterserver_account}

    server_options =
      elem(xml, 2)
      |> List.keyfind(:server_options, 0)
      |> elem(2)
      |> List.keyreplace(:name, 0, {:name, [], [Mppm.XML.charlist(server.name)]})
      |> List.keyreplace(:comment, 0, {:comment, [], [Mppm.XML.charlist(server.comment)]})
      |> List.keyreplace(:max_players, 0, {:max_players, [], [Mppm.XML.charlist(config.max_players)]})
      |> List.keyreplace(:password_spectator, 0, {:password_spectator, [], [Mppm.XML.charlist(config.spec_pwd)]})
      |> List.keyreplace(:password, 0, {:password, [], [Mppm.XML.charlist(config.player_pwd)]})
      |> List.keyreplace(:disable_horns, 0, {:disable_horns, [], [Mppm.XML.charlist(config.disable_horns)]})
      |> List.keyreplace(:keep_player_slots, 0, {:keep_player_slots, [], [Mppm.XML.charlist(config.keep_player_slot)]})
      |> List.keyreplace(:autosave_replays, 0, {:autosave_replays, [], [Mppm.XML.charlist(config.autosave_replays)]})
      |> List.keyreplace(:autosave_validation_replays, 0, {:autosave_validation_replays, [], [Mppm.XML.charlist(config.autosave_validation_replays)]})
      |> List.keyreplace(:clientinputs_maxlatency, 0, {:clientinputs_maxlatency, [], [Mppm.XML.charlist(config.client_inputs_max_latency)]})
    server_options = {:server_options, [], server_options}

    system_config =
      elem(xml, 2)
      |> List.keyfind(:system_config, 0)
      |> elem(2)
      |> List.keyreplace(:force_ip_address, 0, {:force_ip_address, [], [Mppm.XML.charlist(config.ip_address)]})
      |> List.keyreplace(:connection_uploadrate, 0, {:connection_uploadrate, [], [Mppm.XML.charlist(config.connection_upload_rate)]})
      |> List.keyreplace(:connection_downloadrate, 0, {:connection_downloadrate, [], [Mppm.XML.charlist(config.connection_download_rate)]})
      |> List.keyreplace(:workerthreadcount, 0, {:workerthreadcount, [], [Mppm.XML.charlist(config.workers_nb)]})
      |> List.keyreplace(:packetassembly_multithread, 0, {:packetassembly_multithread, [], [Mppm.XML.charlist(config.packet_assembly_multithread)]})
      |> List.keyreplace(:packetassembly_packetsperframe, 0, {:packetassembly_packetsperframe, [], [Mppm.XML.charlist(config.packets_per_frame)]})
      |> List.keyreplace(:packetassembly_fullpacketsperframe, 0, {:packetassembly_fullpacketsperframe, [], [Mppm.XML.charlist(config.full_packets_per_frame)]})
      |> List.keyreplace(:delayedvisuals_s2c_sendingrate, 0, {:delayedvisuals_s2c_sendingrate, [], [Mppm.XML.charlist(config.visuals_server_to_client_sending_rate)]})
      |> List.keyreplace(:trustclientsimu_c2s_sendingrate, 0, {:trustclientsimu_c2s_sendingrate, [], [Mppm.XML.charlist(config.trust_client_to_server_sending_rate)]})
      |> List.keyreplace(:disable_replay_recording, 0, {:disable_replay_recording, [], [Mppm.XML.charlist(config.disable_replay_recording)]})
    system_config = {:system_config, [], system_config}

    new_xml = {:dedicated, [], [authorization_levels, masterserver_account, server_options, system_config]}

    pp = :xmerl.export_simple([new_xml], :xmerl_xml)
    |> List.flatten

    filename = server.login <> ".txt"

    Logger.info "["<>server.login<>"] Writing new config file"
    :file.write_file(@config_path <> filename, pp)

    {:ok, filename}
  end




  #
  # def get_tracks_list(server_login) do
  #   "#{@maps_path}MatchSettings/#{server_login}.txt"
  #   |> get_default_xml
  #   |> elem(2)
  #   |> Enum.filter(fn {key, _attr, _value} -> key == :map end)
  #   |> Enum.map(fn {:map, _, [{_, _, [track_path]}]} ->
  #     %Mppm.Track{
  #       name: clear_filename(track_path)
  #     }
  #   end)
  # end
  #
  # def clear_filename(filename) do
  #   filename
  #   |> List.to_string
  #   |> String.split("/")
  #   |> List.last
  #   |> String.split(".")
  #   |> List.first
  # end
  #
  #
  #
  #


  defp defaults_missing_passwords(data) do
    Enum.reduce @users_pwd, data, fn field, acc ->
      Map.put_new(acc, to_string(field), generate_random_password(12))
    end
  end


  def generate_random_password(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64 |> binary_part(0, length)
  end

end
