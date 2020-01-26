defmodule MppmWeb.DashboardLive do
  use Phoenix.LiveView
  alias Mppm.Repo
  alias MppmWeb.Live.Component.CreateServerForm


  @topic "server_status"


  def render(assigns) do
    MppmWeb.DashboardView.render("index.html", assigns)
  end


  def mount(session, socket) do
    MppmWeb.Endpoint.subscribe(@topic)
    statuses = Mppm.ManiaplanetServer.servers_status()

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
    statuses = Mppm.ManiaplanetServer.servers_status()
    {:noreply, assign(socket, statuses: statuses)}
  end


  def handle_event("create-server", params, socket) do
    {:ok, server} =
      %Mppm.ServerConfig{}
      |> Mppm.ServerConfig.create_server_changeset(params["server_config"])
      |> Repo.insert

    socket =
      socket
      |> assign(servers: [server])
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
