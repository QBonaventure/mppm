defmodule Mppm.Broker.Supervisor do
  use Supervisor


  @xmlrpc_conn_opts [:binary, {:active, true}, {:reuseaddr, true}, {:keepalive, true}, {:send_timeout, 20000}]


  def open_connection(port) do
    :gen_tcp.connect({127, 0, 0, 1}, port, @xmlrpc_conn_opts)
  end


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
