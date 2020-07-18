defmodule Mppm.Controller.Maniacontrol do
  require Logger
  use GenServer
  alias Mppm.ServerConfig

  @mc_config Application.get_env(:mppm, Mppm.Controller.Maniacontrol)
  @mc_root_path @mc_config[:root_path] <> @mc_config[:version] <> "/"
  @config_path @mc_root_path <> "/configs/"
  @default_config_file @mc_root_path <> "/configs/server.default.xml"


  def init(init_arg) do
    {:ok, init_arg}
  end

  def get_command(%ServerConfig{login: name}), do: "/usr/bin/php73 #{@mc_root_path}/ManiaControl.php -config=#{name}.xml -id=#{name}"


  def create_config_file(%{config: server_config, listening_ports: %{"xmlrpc" => xmlport}}) do
    xml = get_base_xml()

    server =
      elem(xml, 2)
      |> List.keyfind(:server, 0)
      |> elem(2)
      |> List.keyreplace(:port, 0, {:port, [], [charlist(xmlport)]})
      |> List.keyreplace(:user, 0, {:user, [], ['SuperAdmin']})
      |> List.keyreplace(:pass, 0, {:pass, [], [charlist(server_config.superadmin_pass)]})
    server = {:server, [id: server_config.login], server}

    database =
      elem(xml, 2)
      |> List.keyfind(:database, 0)
      |> elem(2)
      |> List.keyreplace(:host, 0, {:host, [], [charlist(@mc_config[:db_host])]})
      |> List.keyreplace(:port, 0, {:port, [], [charlist(@mc_config[:db_port])]})
      |> List.keyreplace(:user, 0, {:user, [], [charlist(@mc_config[:db_user])]})
      |> List.keyreplace(:pass, 0, {:pass, [], [charlist(@mc_config[:db_pass])]})
      |> List.keyreplace(:name, 0, {:name, [], [charlist("maniacontrol_" <> server_config.login)]})
    database = {:database, [], database}

    masteradmins =
      elem(xml, 2)
      |> List.keyfind(:masteradmins, 0)
      |> elem(2)
      |> List.keyreplace(:login, 0, {:login, [], ['mr2_md43Qg-_ZeOmUQ32pA']})
    masteradmins = {:masteradmins, [], masteradmins}

    new_xml = {:maniacontrol, [], [server, database, masteradmins]}

    pp = :xmerl.export_simple([new_xml], :xmerl_xml)
    |> List.flatten

    filename = server_config.login <> ".xml"
    :file.write_file(@config_path <> filename, pp)

    filename
  end


  defp charlist(value) when is_binary(value), do: String.to_charlist(value)
  defp charlist(nil = _value), do: []


  def get_base_xml() do
    {result, _misc} = :xmerl_scan.file(@default_config_file, [{:space, :normalize}])
    [clean] = :xmerl_lib.remove_whitespace([result])
    :xmerl_lib.simplify_element(clean)
  end


end
