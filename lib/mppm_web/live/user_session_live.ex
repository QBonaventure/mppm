defmodule MppmWeb.UserSessionLive do
  use Phoenix.LiveView
  alias MppmWeb.AuthView
  alias Mppm.Session.UserSession

  def render(assigns) do
    AuthView.render("user-session.html", assigns)
  end


  def mount(_params, session, socket) do
    Mppm.PubSub.subscribe("user-status")
    user_session = update_user_session_with_pid(session)

    socket =
      socket
      |> assign(user_session: user_session)
    {:ok, socket}
  end

  def handle_info({"username_update", %UserSession{} = user_session}, socket) do
    {:noreply, assign(socket, user_session: user_session)}
  end

  def handle_info({:app_role_updated, user, _role}, socket) do
    session_user =
      socket.assigns.user_session
      |> Map.get("current_user")
      |> Mppm.Session.AgentStore.get()
    case session_user.id == user.id do
      true ->
        session_user = Mppm.Session.UserSession.update_user_role(session_user, user)
        socket = assign(socket, user_session: session_user)
       {:noreply, push_redirect(socket, to: "/")}
      false ->
        {:noreply, socket}
    end
  end


  defp update_user_session_with_pid(%UserSession{nickname: _nickname, component_pid: nil} = session) do
    %UserSession{session | component_pid: self()}
    |> UserSession.update_user_session
  end

  defp update_user_session_with_pid(user_session), do: user_session

end
