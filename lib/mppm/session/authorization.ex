defmodule Mppm.Session.Authorization do
  import Plug.Conn

  def call(conn, opts \\ []) do
    required_roles = Keyword.get(opts, :required_roles)
    %{"current_user" => key} = Plug.Conn.get_session(conn)
    %Mppm.Session.UserSession{role: role} = Mppm.Session.AgentStore.get(key)
    case role in required_roles do
      true ->
        conn
      false ->
          conn
          |> Phoenix.Controller.redirect(to: "/auth/unauthorized.html")
          |> halt()
    end
  end

  def init(opts \\ []) do
    opts
  end


end
