defmodule Mppm.Broker.Supervisor do
  use Supervisor

  def child_spec(game_server_config, xmlrpc_port) do
    %{
      id: __MODULE__,
      start: {
        __MODULE__,
        :start_link,
        [
          [
            game_server_config.login,
            game_server_config.superadmin_pass,
            xmlrpc_port
          ]
        ]
      },
      restart: :transient
    }
  end


  def start_link([login, superadmin_pwd, xmlrpc_port] = init_args, opts \\ []), do:
    Supervisor.start_link(__MODULE__, init_args, name: {:global, {:broker_supervisor, login}})


  def init([login, superadmin_pwd, xmlrpc_port] = init_args) do
    children = [
      {Mppm.Broker.ReceiverServer, [login, xmlrpc_port, superadmin_pwd]},
      {Mppm.Broker.RequesterServer, [login, xmlrpc_port, superadmin_pwd]}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

end
