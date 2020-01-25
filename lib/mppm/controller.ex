defmodule Mppm.Controller do
  alias __MODULE__
  alias Mppm.ServerConfig

  def start_link([%ServerConfig{} = server_config] = args, opts \\ []) do
    GenServer.start_link(__MODULE__, %{server_config: server_config}, name: {:global, {:mp_controller, server_config.name}})
  end


  # def init(%{server_config: server_config} = args) do
  #   {:ok, port} = start_controller(server_config)
  #   {:ok, %{port: port, os_pid: Port.info(port, :os_pid), exit_status: nil, listening_ports: nil, latest_output: nil, status: "running",  config: server_config}}
  # end


end
