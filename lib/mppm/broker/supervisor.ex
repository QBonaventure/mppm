defmodule Mppm.Broker.Supervisor do
  use Supervisor

  def child_spec(game_server, xmlrpc_port) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[
          game_server.login,
          game_server.config.superadmin_pass,
          xmlrpc_port
        ]]
      },
      restart: :transient
    }
  end


  def start_link([login, _superadmin_pwd, _xmlrpc_port] = init_args, _opts \\ []), do:
    Supervisor.start_link(__MODULE__, init_args, name: {:global, {:broker_supervisor, login}})


  def init([login, superadmin_pwd, xmlrpc_port]) do
    children = [
      {Mppm.Broker.ReceiverServer, [login, xmlrpc_port, superadmin_pwd]},
      {Mppm.Broker.RequesterServer, [login, xmlrpc_port, superadmin_pwd]}
    ]
    Supervisor.init(children, strategy: :rest_for_one)
  end

end
