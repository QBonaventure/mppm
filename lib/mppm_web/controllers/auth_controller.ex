defmodule MppmWeb.AuthController do
  use MppmWeb, :controller
  alias Mppm.{Repo,User}
  plug :put_layout, "auth.html"


  def callback(conn, %{"code" => code, "service" => "trackmania", "state" => _state}) do
    result =
      Mppm.Service.Trackmania.get_token!([code: code])
      |> Map.get(:token)
      |> Mppm.Service.Trackmania.get_user

    case result do
      {:ok, user} ->
        {conn, message} = Mppm.Session.UserSession.set_user_session(conn, user)
        conn
        |> put_flash(:info, message)
        |> redirect(to: "/")
      {:error, reason} ->
        conn
        |> put_flash(:info, reason)
        |> redirect(to: "/auth/login.html")
    end
  end


  def login(conn, gg) do
    conn
    |> render("login.html")
  end


  def logout(conn, _) do
    conn
    |> Mppm.Session.UserSession.clear
    |> redirect(to: "/auth/login.html")
  end

end
