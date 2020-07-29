defmodule Mppm.ServerConfig do
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
  @root_path Application.get_env(:mppm, :mp_servers_root_path)
  @config_path @root_path <> "UserData/Config/"
  @maps_path @root_path <> "UserData/Maps/"

  schema "mp_servers_configs" do
    has_one :ruleset, Mppm.GameRules, foreign_key: :server_id, on_replace: :update
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
    field :keep_player_slot, :boolean
    field :disable_horns, :boolean
    field :ip_address, EctoNetwork.INET
    field :bind_ip, EctoNetwork.INET
    field :autosave_replays, :boolean
    field :autosave_validation_replays, :boolean

  end

  def get_all() do
    Mppm.Repo.all(Mppm.ServerConfig)
    |> Mppm.Repo.preload(ruleset: [:mode])
  end

  def get_server_config(server_login) do
    Mppm.Repo.get_by(Mppm.ServerConfig, login: server_login)
    |> Mppm.Repo.preload(ruleset: [:mode])
  end


  @required [:login, :password, :max_players]
  @users_pwd [:superadmin_pass, :admin_pass, :user_pass]
  def create_server_changeset(%ServerConfig{} = server_config \\ %ServerConfig{}, data \\ %{}) do
    data = defaults_missing_passwords(data) |> Map.put_new("mode_id", 1)
#     |> Map.put("ruleset", %Mppm.GameRules{})
# IO.inspect data
    server_config
    |> cast(data, [
      :login, :password, :name, :comment, :player_pwd, :spec_pwd,
      :max_players, :superadmin_pass, :admin_pass, :user_pass,
      :ip_address
      ])
    |> put_assoc(:ruleset, %Mppm.GameRules{})
    |> validate_required(@required)
  end

  def changeset(%ServerConfig{} = config, params) do
    config
    |> cast(params, [:name, :comment, :player_pwd, :spec_pwd, :max_players, :ip_address])
    |> cast_assoc(:ruleset)
  end


  def create_new_server(game_server_config) do
    %ServerConfig{}
    |> ServerConfig.create_server_changeset(game_server_config)
    |> Repo.insert
  end

  def update(changeset) do
    case changeset |> Repo.update do
      {:ok, server_config} ->
        IO.inspect :global.whereis_name({:mp_proc, server_config.login})
        IO.inspect propagate_ruleset_changes(:global.whereis_name({:mp_broker, server_config.login}), changeset)
      {:error, changeset} ->
        {:ok, nil}
    end
  end


  def propagate_ruleset_changes(pid, %Ecto.Changeset{changes: %{ruleset: %Ecto.Changeset{changes: changes}}} = data)
  when is_pid(pid) do
    mode_vars = Mppm.GameRules.get_script_variables_by_mode(data.data.ruleset.mode)
    to_update = Enum.filter(changes, fn {key, value} -> Map.has_key?(mode_vars, key) end)
    GenServer.call(pid, {:update_ruleset, to_update})
    case switch_game_mode?(changes) do
      true -> GenServer.call(pid, {:switch_game_mode, Mppm.Repo.get(Mppm.Type.GameMode, changes.mode_id)})
      false ->
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
      |> List.keyreplace(:password_spectator, 0, {:password_spectator, [], []})
      |> List.keyreplace(:password, 0, {:password, [], [charlist(serv_config.player_pwd)]})
      |> List.keyreplace(:disable_horns, 0, {:disable_horns, [], [charlist(serv_config.disable_horns)]})
      |> List.keyreplace(:keep_player_slots, 0, {:keep_player_slots, [], [charlist(serv_config.keep_player_slot)]})
      |> List.keyreplace(:autosave_replays, 0, {:autosave_replays, [], [charlist(serv_config.autosave_replays)]})
      |> List.keyreplace(:autosave_validation_replays, 0, {:autosave_validation_replays, [], [charlist(serv_config.autosave_validation_replays)]})
    server_options = {:server_options, [], server_options}

    system_config =
      elem(xml, 2)
      |> List.keyfind(:system_config, 0)
      |> elem(2)
      |> List.keyreplace(:force_ip_address, 0, {:force_ip_address, [], [charlist(serv_config.ip_address)]})

    system_config = {:system_config, [], system_config}

    new_xml = {:dedicated, [], [authorization_levels, masterserver_account, server_options, system_config]}

    pp = :xmerl.export_simple([new_xml], :xmerl_xml)
    |> List.flatten

    filename = serv_config.login <> ".txt"
    :file.write_file(@config_path <> filename, pp)

    filename
  end

  def get_tracks_list(server_login) do
    "#{@maps_path}MatchSettings/#{server_login}.txt"
    |> get_default_xml
    |> elem(2)
    |> Enum.filter(fn {key, attr, value} -> key == :map end)
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

  def create_tracklist(%ServerConfig{login: login}) do
    target_path = "#{@maps_path}MatchSettings/#{login}.txt"
    source_path = "#{@maps_path}MatchSettings/example.txt"

    xml = get_default_xml(source_path)

    game_rules =
      elem(xml, 2)
      |> List.keyfind(:gameinfos, 0)
      |> elem(2)
      # |> List.keyreplace()


    'ls #{target_path} >> /dev/null 2>&1 || cp #{source_path} #{target_path}'
    |> :os.cmd
  end


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
