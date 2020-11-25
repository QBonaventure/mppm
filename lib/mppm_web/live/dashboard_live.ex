defmodule MppmWeb.DashboardLive do
  use Phoenix.LiveView

  @statuses Mppm.ServersStatuses.get_statuses_list()


  def render(assigns) do
    MppmWeb.DashboardView.render("index.html", assigns)
  end


  def mount(_params, session, socket) do
    MppmWeb.Endpoint.subscribe("server-status")

    socket =
      socket
      |> assign(changeset: Mppm.ServerConfig.create_server_changeset())
      |> assign(disabled_submit: true)
      |> assign(servers: Mppm.ServersStatuses.all)
      |> assign(user_session: session)

    {:ok, socket}
  end


  def get_changeset(params) do
    changeset =
      Mppm.ServerConfig.create_server_changeset(%Mppm.ServerConfig{}, params)

    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:error, changeset} ->
        {:ok, changeset}
      {:ok, _ } ->
        {:ok, changeset}
    end
  end



  def handle_info({server_status, server_login}, socket)
  when server_status in @statuses, do:
    {:noreply, assign(socket, servers: Kernel.put_in(socket.assigns.servers, [server_login, :status], server_status))}


  def handle_info(_unhandled_info, socket), do:
    {:noreply, socket}



  def handle_event("create-server", params, socket) do
    {:ok, server_config} = Mppm.ServerConfig.create_new_server(params["server_config"])
    Mppm.GameServer.Supervisor.start_server_supervisor(server_config)

    socket =
      socket
      |> assign(servers: Mppm.ServersStatuses.all)
      |> assign(changeset: Mppm.ServerConfig.create_server_changeset())

    {:noreply, socket}
  end


  def handle_event("validate", params, socket) do
    {:ok, changeset} =  get_changeset(params["server_config"])
    {:noreply, assign(socket, changeset: changeset)}
  end


  def handle_event("cancel-form", _params, socket) do
    {:noreply, assign(socket, changeset: Mppm.ServerConfig.create_server_changeset())}
  end

end
