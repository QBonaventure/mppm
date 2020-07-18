defmodule MppmWeb.DashboardLive do
  use Phoenix.LiveView
  alias Mppm.Repo


  @topic "server_status"


  def render(assigns) do
    MppmWeb.DashboardView.render("index.html", assigns)
  end


  def mount(_params, _session, socket) do
    MppmWeb.Endpoint.subscribe(@topic)
    statuses = Mppm.Statuses.all

    servers = Repo.all(Mppm.ServerConfig)
    socket =
      socket
      |> assign(changeset: Mppm.ServerConfig.create_server_changeset())
      |> assign(disabled_submit: true)
      |> assign(servers: servers)
      |> assign(statuses: statuses)

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



  def handle_info(:update, socket) do
    {:noreply, assign(socket, statuses: Mppm.Statuses.all)}
  end


  def handle_event("create-server", params, socket) do
    {:ok, server_config} = Mppm.ServerConfig.create_new_server(params["server_config"])
    Mppm.ManiaplanetServerSupervisor.start_server_supervisor(server_config)

    socket =
      socket
      |> assign(statuses: Mppm.Statuses.all())
      |> assign(servers: [server_config | socket.assigns.servers])
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
