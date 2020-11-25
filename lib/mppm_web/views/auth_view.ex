defmodule MppmWeb.AuthView do
  use MppmWeb, :view

  def user_logged_in?(%Plug.Conn{} = conn) do
    case Plug.Conn.get_session(conn, :current_user) do
      nil -> false
      _key -> true
    end
  end

  @spec get_session(%Plug.Conn{}) :: nil | %Mppm.Session.UserSession{}
  def get_session(conn) do
    case Plug.Conn.get_session(conn, :current_user) do
      nil -> nil
      key ->
        case session = Mppm.Session.AgentStore.get(key) do
          nil ->
            Mppm.Session.UserSession.clear(conn)
            nil
          _ -> session

        end
    end
  end

end
