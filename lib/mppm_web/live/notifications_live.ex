defmodule MppmWeb.NotificationsLive do
  use Phoenix.LiveView

  def render(assigns) do
    MppmWeb.NotificationsView.render("main.html", assigns)
  end


  def mount(_params, session, socket) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "notifications")

    socket =
      socket
      |> assign(notifications: [])
    {:ok, socket}
  end

  def handle_info({:new_notification, %Mppm.Note{} = note}, socket) do
    Process.send_after(self(), {:remove_notification, note}, 3000)
    {:noreply, assign(socket, :notifications, socket.assigns.notifications ++ [note])}
  end

  def handle_info({:remove_notification, %Mppm.Note{} = note}, socket) do
    socket = assign(socket, notifications: Enum.reject(socket.assigns.notifications, & &1 == note))
    {:noreply, socket}
  end

end
