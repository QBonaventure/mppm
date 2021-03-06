defmodule MppmWeb.DashboardLive do
  use Phoenix.LiveView

  @statuses Mppm.ServersStatuses.get_statuses_list()


  def render(assigns) do
    MppmWeb.DashboardView.render("index.html", assigns)
  end


  def mount(_params, session, socket) do
    servers = Mppm.ServersStatuses.all()
    servers_versions = Mppm.Service.UbiNadeoApi.server_versions() |> elem(1)
    servers_ids = Mppm.ServersStatuses.all() |> Enum.map(fn {_name, server} -> server.config.id end)

    socket =
      socket
      |> assign(new_server_changeset: Mppm.ServerConfig.create_server_changeset())
      |> assign(disabled_submit: true)
      |> assign(servers_ids: servers_ids)
      |> assign(user_session: session)
      |> assign(server_versions: Mppm.GameServer.DedicatedServer.ready_to_use_servers())

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

  def handle_params(%{}, uri, socket) do
    {:noreply, socket}
  end

  def handle_info({status, server_login}, socket)
  when status in [:started, :starting, :stopped, :stopping] do
    send_update(MppmWeb.Live.Component.ServerLine, id: Mppm.ServersStatuses.server_id(server_login), status: status)
    {:noreply, socket}
  end

  def handle_info(_unhandled_info, socket) do
    {:noreply, socket}
  end



  def handle_event("create-server", params, socket) do
    {:ok, server_config} = Mppm.ServerConfig.create_new_server(params["server_config"])
    Mppm.GameServer.Supervisor.start_server_supervisor(server_config)
    socket =
      socket
      |> assign(servers: Mppm.ServersStatuses.all)
      |> assign(new_server_changeset: Mppm.ServerConfig.create_server_changeset())

    {:noreply, socket}
  end


  def handle_event("validate", params, socket) do
    {:ok, changeset} =  get_changeset(params["server_config"])
    {:noreply, assign(socket, new_server_changeset: changeset)}
  end


  def handle_event("cancel-form", _params, socket) do
    {:noreply, assign(socket, new_server_changeset: Mppm.ServerConfig.create_server_changeset())}
  end

end
