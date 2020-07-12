defmodule Mppm.Controller do
  require Logger
  use GenServer
  alias Mppm.ServerConfig


  def child_spec(mp_server_state) do
    IO.inspect mp_server_state
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
    state =  %{
      login: config.login,
      port: nil,
      os_pid: nil,
      exit_status: nil,
      listening_ports: state.listening_ports,
      latest_output: nil,
      status: "stopped",
      config: config
    }

    {:ok, state}
  end


  def start_server(%{config: config} = state) do
    controller =
      case config.controller do
        "maniacontrol" -> Mppm.Controller.Maniacontrol
        "pyplanet" -> Mppm.Controller.Pyplanet
      end

    controller.create_config_file(state)
    command = controller.get_command(state.config)
    port = Port.open({:spawn, command}, [:binary, :exit_status])
    Port.monitor(port)

    {:ok, port}
  end


  def handle_call({:start, mp_server_state}, _, state) do
    update_status(state.login, "starting")
    {:ok, port} = start_server(mp_server_state)
    update_status(state.login, "started")

    {:reply, :result, %{state | status: "started", port: port, login: mp_server_state.config.login}}
  end


  ###################################
  ##### STOP FUNCTIONS ##############
  ###################################

  def stop_server(state) do
    GenServer.cast(self(), :closing_port)
    {:os_pid, pid} = Port.info(state.port, :os_pid)
    Port.close(state.port)
    System.cmd("kill", ["-9", "#{pid}"])

    update_status(state.login, "stopped")
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server_status", :update)
    {:ok, state}
  end


  def handle_call(:stop, _, state) do
    stop_server(state)
    {:reply, {:ok, self()}, state}
  end


  def handle_cast(:closing_port, state) do
    {:noreply, %{state | exit_status: :port_closed, status: "stopped"}}
  end


  def handle_info(:stop, state) do
    stop_server(state)
    {:noreply, %{state | exit_status: :port_closed, status: "stopped"}}
  end


  def handle_info({:DOWN, _ref, :port, port, :normal}, %{exit_status: :port_closed} = state) do
    Logger.info "Controller successfully stopped through Port: #{inspect port}"

    {:noreply, state}
  end


  def handle_call(:pid, _, state) do
    {:reply, self, state}
  end


  def handle_call(:status, _, state) do
    {:reply, %{state: state.status, port: state.port, os_pid: state.os_pid}, state}
  end


  def handle_info({_port, {:data, text_line}}, state) do
    Logger.info text_line

    {:noreply, state}
  end


  def handle_info({_port, {:exit_status, status}}, state) do
    Logger.info "External exit: :exit_status: #{status}"
    update_status(state.login, "stopped")

    {:noreply, %{state | exit_status: status}}
  end


  def handle_info({:DOWN, _ref, :port, port, :normal}, %{exit_status: 137} = state) do
    update_status(state.login, "failed")
    {:noreply, %{state | status: "crashed"}}
  end


  def handle_info({:DOWN, _ref, :port, port, :normal}, %{exit_status: 0} = state) do
    update_status(state.login, "failed")
    {:noreply, %{state | status: "failed"}}
  end

  def update_status(login, status) do
    IO.inspect login
    Mppm.Statuses.update_controller(login, status)
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server_status", :update)
    {:ok, status}
  end


end
