defmodule MppmWeb.UserSessionLive do
  use Phoenix.LiveView
  alias __MODULE__
  alias MppmWeb.AuthView
  alias Mppm.{Repo}
  alias Mppm.Session.UserSession

  def render(assigns) do
    AuthView.render("user-session.html", assigns)
  end


  def mount(_params, session, socket) do
    user_session = update_user_session_with_pid(session)
    socket =
      socket
      |> assign(user_session: user_session)

    {:ok, socket}
  end


  def handle_info({"username_update", %UserSession{} = user_session}, socket) do
    {:noreply, assign(socket, user_session: user_session)}
  end


  @spec update_user_session_with_pid(%UserSession{}) :: %UserSession{}
  defp update_user_session_with_pid(%UserSession{nickname: nickname, component_pid: nil} = session) do
    %UserSession{session | component_pid: self()}
    |> UserSession.update_user_session
  end

  @spec update_user_session_with_pid(%UserSession{} | nil) :: %UserSession{} | nil
  defp update_user_session_with_pid(user_session), do: user_session

end
