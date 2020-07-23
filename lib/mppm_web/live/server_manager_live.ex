defmodule MppmWeb.ServerManagerLive do
  use Phoenix.LiveView
  alias Mppm.Repo

  def render(assigns) do
    MppmWeb.ServerManagerView.render("index.html", assigns)
  end

  def mount(params, _session, socket) do

    server_config = Mppm.ServerConfig.get_server_config(params["server_login"])
    changeset = Ecto.Changeset.change(server_config)
        IO.inspect changeset

    socket =
      socket
      |> assign(changeset: changeset)
      |> assign(server_info: server_config)

    {:ok, socket}
  end


  def handle_event("update-config", params, socket) do
    {:ok, changeset} = get_changeset(socket.assigns.server_info.id, params["server_config"])
    Mppm.ServerConfig.update(changeset)

    {:noreply, socket}
  end



  def handle_event("validate", params, socket) do
    {:ok, changeset} = get_changeset(socket.assigns.server_info.id, params["server_config"])

    {:noreply, assign(socket, changeset: changeset)}
  end


  def get_changeset(server_id, params) do
    changeset =
      Mppm.ServerConfig
      |> Mppm.Repo.get_by(%{id: server_id})
      |> Mppm.Repo.preload(ruleset: [:mode])
      |> Mppm.ServerConfig.changeset(params)

    case Ecto.Changeset.apply_action(changeset, :update) do
      {:error, changeset} ->
        {:ok, changeset}
      {:ok, _ } ->
        {:ok, changeset}
    end
  end

end
