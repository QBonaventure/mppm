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

  def broker_pname(server_login), do: {:global, {:mp_broker, server_login}}


  def handle_event("update-config", params, socket) do
    {:ok, changeset} = get_changeset(socket.assigns.server_info.id, params["server_config"])
    Mppm.ServerConfig.update(changeset)

    {:noreply, socket}
  end


  def handle_event("skip-map", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :skip_map)
    {:noreply, socket}
  end

  def handle_event("restart-map", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :restart_map)
    {:noreply, socket}
  end

  def handle_event("end-round", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :end_round)
    {:noreply, socket}
  end

  def handle_event("end-warmup", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :end_warmup)
    {:noreply, socket}
  end

  def handle_event("end-all-warmup", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :end_all_warmup)
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
