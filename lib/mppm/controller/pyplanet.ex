defmodule Mppm.Controller.Pyplanet do
  require Logger
  use GenServer
  alias Mppm.ServerConfig


  @pp_configs Application.get_env(:mppm, Mppm.Controller.Pyplanet)
  @servers_configs_root @pp_configs[:root_path]


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
    IO.inspect(Port.info(port, :os_pid))
    {:ok, %{port: port, os_pid: Port.info(port, :os_pid), exit_status: nil, listening_ports: nil, latest_output: nil, status: "running", config: config}}
  end


  def get_command(%ServerConfig{login: name}),
    do: "#{@pp_configs[:root_path]}#{name}/manage.py start --pid-file #{name}.pid"


  def start_server(%{config: config} = state) do
    :ok = create_config_file(state)
    command = get_command(config)
    IO.inspect command
    port = Port.open({:spawn, command}, [:binary, :exit_status])
    Port.monitor(port)

    {:ok, port}
  end


  def create_config_file(%{config: server_config, listening_ports: %{"xmlrpc" => xmlport}}) do
    {:ok, base} = get_default_config_file("base")
    {:ok, apps} = get_default_config_file("apps")

    copy_default_folder(server_config)

    manage_filepath = @servers_configs_root <> server_config.login <> "/manage.py"
    updated_manage_content =
      File.read!(manage_filepath)
      |> String.replace("/default", "/#{server_config.login}")
    File.write(manage_filepath, updated_manage_content)

    create_db(server_config)

    base =
      base
      |> Kernel.put_in(["dedicated", "default", "PORT"], xmlport)
      |> Kernel.put_in(["dedicated", "default", "PASSWORD"], server_config.superadmin_pass)
      |> Kernel.put_in(["DATABASES", "default", "OPTIONS", "host"], @pp_configs[:db_host])
      |> Kernel.put_in(["DATABASES", "default", "OPTIONS", "user"], @pp_configs[:db_user])
      |> Kernel.put_in(["DATABASES", "default", "OPTIONS", "password"], @pp_configs[:db_pass])
      |> Kernel.put_in(["DATABASES", "default", "NAME"], "pp_" <> server_config.login)
      |> Kernel.put_in(["POOLS"], [server_config.login])
      |> Jason.encode!
      |> String.replace("default", server_config.login)

    apps =
      apps
      |> Jason.encode!
      |> String.replace("default", server_config.login)

    @servers_configs_root <> server_config.login <> "/settings/base.json"
    |> File.write(base)

    @servers_configs_root <> server_config.login <> "/settings/apps.json"
    |> File.write(apps)

    :ok
  end


  defp charlist(value) when is_binary(value), do: String.to_charlist(value)
  defp charlist(nil = _value), do: []


  def copy_default_folder(%Mppm.ServerConfig{login: name}) do
    File.cp_r(
      @servers_configs_root <> "default",
      @servers_configs_root <> name,
      fn _, _ -> true end
    )
  end

  def get_default_config_file(filename) when filename in ["apps", "base"] do
    @servers_configs_root <> "default/settings/#{filename}.json"
    |> File.read!
    |> Jason.decode
  end

  def create_db(%ServerConfig{login: name}) do
    Mppm.Repo.query("CREATE DATABASE pp_#{name} OWNER #{@pp_configs[:db_user]}")
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
