defmodule MppmWeb.DashboardLive do
  use Phoenix.LiveView


  def render(assigns) do
    MppmWeb.DashboardView.render("index.html", assigns)
  end


  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(new_server_changeset: Mppm.ServerConfig.create_server_changeset())
      |> assign(disabled_submit: true)
      |> assign(servers_ids: Mppm.GameServer.Server.ids_list())
      |> assign(user_session: session)
      |> assign(server_versions: Mppm.GameServer.DedicatedServer.ready_to_use_servers())

    {:ok, socket}
  end


  def get_changeset(params) do
    changeset =
      Mppm.ServerConfig.create_server_changeset(%Mppm.ServerConfig{}, params)

    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:error, changeset} ->
        {:ok, {:invalid, changeset}}
      {:ok, _ } ->
        {:ok, {:valid, changeset}}
    end
  end

  def handle_params(%{}, _uri, socket) do
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



  def handle_event("create-server", %{"server_config" => params}, socket) do
    socket =
      with {:ok, {:valid, changeset}} <- get_changeset(params),
        {:ok, server_config} <- Mppm.GameServer.Server.create_new_server(changeset) do
          socket
          |> assign(servers_ids: socket.assigns.servers_ids ++ [server_config.id])
          |> assign(new_server_changeset: Mppm.ServerConfig.create_server_changeset())
      else
        {:ok, {:invalid, changeset}} ->
          assign(socket, new_server_changeset: changeset)
        {:error, {:insert_fail, changeset}} ->
          assign(socket, new_server_changeset: changeset)
      end
    {:noreply, socket}
  end

  def handle_event("delete-game-server", %{"server-id" => server_id}, socket) do
    server_id = String.to_integer(server_id)
    {:ok, _server_config} =
      Mppm.Repo.get(Mppm.ServerConfig, server_id)
      |> Mppm.GameServer.Server.delete_game_server()
    servers_ids = Enum.reject(socket.assigns.servers_ids, & &1 == server_id)
    {:noreply, assign(socket, servers_ids: servers_ids)}
  end


  def handle_event("validate", params, socket) do
    {:ok, {_status, changeset}} =  get_changeset(params["server_config"])
    {:noreply, assign(socket, new_server_changeset: changeset)}
  end


  def handle_event("cancel-form", _params, socket) do
    {:noreply, assign(socket, new_server_changeset: Mppm.ServerConfig.create_server_changeset())}
  end

end
