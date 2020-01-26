defmodule Mppm.Controller do

  alias Mppm.ServerConfig


  defmacro __using__(_opts) do
    quote do
      defdelegate gg(), to: Mppm.Controller
      defdelegate handle_info(gg, kk), to: Mppm.Controller
    end
  end
  # def start_link([%ServerConfig{} = server_config] = args, opts \\ []) do
  #   GenServer.start_link(__MODULE__, %{server_config: server_config}, name: {:global, {:mp_controller, server_config.name}})
  # end


  # def init(%{server_config: server_config} = args) do
  #   {:ok, port} = start_controller(server_config)
  #   {:ok, %{port: port, os_pid: Port.info(port, :os_pid), exit_status: nil, listening_ports: nil, latest_output: nil, status: "running",  config: server_config}}
  # end

  def handle_info({:DOWN, _ref, :port, port, :normal}, %{exit_status: 137} = state) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server_status", :update)
    {:stop, "Crash of controller process", state}
  end

  def handle_info("ll", "mm") do
    IO.puts "HALLO"
  end

  def gg, do: "GG"


end
