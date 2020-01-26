defmodule Mppm.Controller.Maniacontrol do
  require Logger
  use GenServer
  alias Mppm.ServerConfig


  @mc_config Application.get_env(:mppm, Mppm.Controller.Maniacontrol)
  # @path "./ManiaControl/ManiaControl-170120/"
  @app_path Application.get_env(:mppm, :app_path)
  # @comm "/usr/bin/php73 /opt/maniacontrol/ManiaControl.php -config=#{name}.xml -id=#{name} > /dev/null 2>/dev/null"

  @mc_root_path @mc_config[:root_path] <> @mc_config[:version] <> "/"
  @config_path @mc_root_path <> "/configs/"
  @default_config_file @mc_root_path <> "/configs/server.default.xml"


  def child_spec(mp_server_state) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[mp_server_state], []]},
      restart: :transient,
      name: {:global, {:mp_controller, mp_server_state.config.login}}
    }
  end

  def start_link([%{config: config}] = state, _opts \\ []) do
    GenServer.start_link(__MODULE__, state, name: {:global, {:mp_controller, config.login}})
  end


  def init([%{config: config} = state]) do
    {:ok, port} = start_server(state)
    {:ok, %{port: port, os_pid: Port.info(port, :os_pid), exit_status: nil, listening_ports: nil, latest_output: nil, status: "running", config: config}}
  end


  def get_command(%ServerConfig{login: name}), do: "/usr/bin/php73 #{@mc_root_path}/ManiaControl.php -config=#{name}.xml -id=#{name}"


  def start_server(%{config: config} = state) do
    create_config_file(state)
    command = get_command(config)
    port = Port.open({:spawn, command}, [:binary, :exit_status])
    Port.monitor(port)

    {:ok, port}
  end


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
      |> List.keyreplace(:login, 0, {:login, [], ['rrrazzziel']})
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


  def handle_call(:status, _, state) do
    {:os_pid, pid} = state.os_pid
    {:reply, %{state: state.status, port: state.port, os_pid: pid}, state}
  end


  def handle_info({_port, {:data, text_line}}, state) do
    latest_output = text_line |> String.trim

    Logger.info "Contr. #{latest_output}"

    {:noreply, %{state | latest_output: latest_output}}
  end


  def handle_info({_port, {:exit_status, status}}, state) do
    Logger.info "External exit: :exit_status: #{status}"

    {:noreply, %{state | exit_status: status}}
  end

  def handle_info({:DOWN, _ref, :port, port, :normal}, %{exit_status: 137} = state) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server_status", :update)
    {:stop, "Crash of controller process", %{state | status: "crashed"}}
  end


end
