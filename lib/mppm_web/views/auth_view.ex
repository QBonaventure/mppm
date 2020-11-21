defmodule MppmWeb.AuthView do
  use MppmWeb, :view
  alias Plug.Conn
  alias Mppm.Session.{AgentStore,UserSession}

  def ext_service_login_link(ext_service) do
    Mppm.Service.Trackmania.authorize_url

  end

  def user_logged_in?(%Conn{} = conn) do
    case Conn.get_session(conn, :current_user) do
      nil -> false
      _key -> true
    end
  end

  @spec get_session(%Conn{}) :: nil | %UserSession{}
  def get_session(conn) do
    case Conn.get_session(conn, :current_user) do
      nil -> nil
      key ->
        case session = AgentStore.get(key) do
          nil ->
            UserSession.clear(conn)
            nil
          _ -> session

        end
    end
  end

end
