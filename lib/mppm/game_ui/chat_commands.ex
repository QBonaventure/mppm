defmodule Mppm.GameUI.ChatCommands do
  use GenServer

  @behaviour Mppm.GameUI.Module

  def name(), do: "ChatCommands"


  def execute("hello", _input) do
    :ok
  end

  def execute(_unknown_command, _input) do
    :unknown_command
  end

  ##############################################################################
  ############################ GenServer Callbacks #############################
  ##############################################################################

  def handle_info({:new_chat_message, %Mppm.ChatMessage{text: "/"<>input}}, state) do
    [command, input] = String.split(input<>" ", " ", parts: 2)
    IO.inspect {command, input}
    execute(command, input)
    {:noreply, state}
  end

  def handle_info(_unhandled_message, state) do
    {:noreply, state}
  end


  ##############################################################################
  ############################## GenServer Impl. ###############################
  ##############################################################################

  def child_spec([server_login]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[server_login]]},
      restart: :transient
    }
  end

  def start_link([server_login], _opts \\ []),
    do: GenServer.start_link(__MODULE__, [server_login], name: {:global, {__MODULE__, server_login}})

  def init([server_login]) do
    Process.flag(:trap_exit, true)
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "server-status")

    Mppm.GameUI.Helper.log_module_start(server_login, name())

    {:ok, %{server_login: server_login}, {:continue, :init_continue}}
  end

  def handle_continue(:init_continue, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    :normal
  end

end
