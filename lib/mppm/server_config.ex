defmodule Mppm.ServerConfig do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias Mppm.ServerConfigStore
  import Record
  defrecord(:xmlElement, extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl"))
  defrecord(:xmlAttribute, extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl"))
  defrecord(:xmlText, extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl"))

  @app_path Application.get_env(:mppm, :app_path)
  @root_path Application.get_env(:mppm, :mp_servers_root_path)
  @config_path @root_path <> "UserData/Config/"
  @maps_path @root_path <> "UserData/Maps/"

  schema "mp_servers_configs" do
    field :login, :string
    field :password, :string
    field :title_pack, :string
    field :name, :string
    field :comment, :string
    field :max_players, :integer, default: 32
    field :player_pwd, :string
    field :spec_pwd, :string
    field :superadmin_pass, :string
    field :admin_pass, :string
    field :user_pass, :string
    field :controller, :string
  end


  @required [:login, :password, :title_pack, :max_players, :controller]
  @users_pwd [:superadmin_pass, :admin_pass, :user_pass]
  def create_server_changeset(%ServerConfig{} = server_config \\ %ServerConfig{}, data \\ %{}) do
    data = defaults_missing_passwords(data)

    server_config
    |> cast(data, [:login, :password, :name, :comment, :title_pack, :controller, :player_pwd, :spec_pwd, :max_players, :superadmin_pass, :admin_pass, :user_pass])
    |> validate_required(@required)
  end


  def defaults_missing_passwords(data) do
    Enum.reduce @users_pwd, data, fn field, acc ->
      Map.put_new(acc, to_string(field), generate_random_password(12))
    end
  end


  def generate_random_password(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64 |> binary_part(0, length)
  end


  def create_config_file(%ServerConfig{} = serv_config) do
    xml = get_base_xml()

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
      |> List.keyreplace(:validation_key, 0, {:validation_key, [], [charlist(Application.get_env(:mppm, :masteraccount_validation_key))]})
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
    server_options = {:server_options, [], server_options}

    system_config =
      elem(xml, 2)
      |> List.keyfind(:system_config, 0)
      |> elem(2)
    system_config = {:system_config, [], system_config}

    new_xml = {:dedicated, [], [authorization_levels, masterserver_account, server_options, system_config]}

    pp = :xmerl.export_simple([new_xml], :xmerl_xml)
    |> List.flatten

    filename = serv_config.login <> ".txt"
    :file.write_file(@config_path <> filename, pp)

    filename
  end


  def create_tracklist(%ServerConfig{login: login}) do
    target_path = "#{@maps_path}MatchSettings/#{login}.txt"
    source_path = "#{@maps_path}MatchSettings/tracklist.txt"

    'ls #{target_path} >> /dev/null 2>&1 || cp #{source_path} #{target_path}'
    |> :os.cmd
  end

  defp charlist(value) when is_binary(value), do: String.to_charlist(value)
  defp charlist(value) when is_integer(value), do: Integer.to_string(value) |> String.to_charlist
  defp charlist(nil = value), do: []


  def get_base_xml() do
    {result, _misc} =
      @config_path <> "dedicated_cfg.default.txt"
      |>:xmerl_scan.file([{:space, :normalize}])
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
