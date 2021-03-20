defmodule Mppm.Session.UserSession do
  alias __MODULE__
  alias Mppm.Session.AgentStore
  alias Ecto.Changeset
  import Plug.Conn

  defstruct [
    key: nil,
    id: nil,
    nickname: nil,
    uuid: nil,
    component_pid: nil,
    role: :user
  ]

  def current_user(conn), do: conn.assigns[:current_user]
  def logged_in?(conn), do: !!current_user(conn)

  def init(opts \\ []) do
    %{error: opts[:error] || "Not authorized"}
  end

  def call(conn, _opts\\ []) do
    if user = get_user(conn) do
      assign(conn, :current_user, user)
    else
      conn
      |> Phoenix.Controller.redirect(to: "/auth/login.html")
      |> halt()
    end
  end


  def from_user(%Mppm.User{app_roles: %Ecto.Association.NotLoaded{}} = user),
    do: user |> Mppm.Repo.preload([:app_roles]) |> from_user()
  def from_user(%Mppm.User{id: id, nickname: nickname, uuid: uuid, app_roles: roles}) do
    %UserSession{
      key: :crypto.strong_rand_bytes(18) |> Base.url_encode64,
      id: id,
      nickname: nickname,
      uuid: uuid,
      role: get_role(roles)
    }
  end


  def clear(conn) do
    Plug.Conn.clear_session(conn)
  end

  def update_user_session(%UserSession{} = user_session) do
    AgentStore.update(user_session.key, user_session)
    user_session
  end

  def update_user_session(%UserSession{} = user_session, %Changeset{data: %Mppm.User{}, changes: %{name: nickname}}) do
    user_session = %{user_session | nickname: nickname}
    AgentStore.update(user_session.key, user_session)

    user_session
  end

  def update_user_session(%UserSession{} = user_session, %Changeset{data: %Mppm.User{}, changes: %{}}) do
    user_session
  end

  # def update_user_role(%UserSession{} = user_session, %Mppm.User{roles: %Ecto.Association.NotLoaded{}} = user) do
  #   user = Mppm.Repo.preload(user, [:roles])
  #   update_user_role(user_session, user)
  # end
  def update_user_role(%UserSession{} = user_session, %Mppm.User{} = user) do
    user_session = %{user_session | role: get_role(user.app_roles)}
    AgentStore.update(user_session.key, user_session)
    user_session
  end


  @spec set_user_session(%Plug.Conn{}, %Mppm.User{}) :: {%Plug.Conn{}, String.t}
  def set_user_session(conn, %Mppm.User{} = user) do
      {user_session, message} = create_user_session(user)

      AgentStore.create(user_session)
      conn = put_session(conn, :current_user, user_session.key)

      {conn, message}
  end


  @spec create_user_session(%Mppm.User{}) :: {%UserSession{}, String.t}
  defp create_user_session(%Mppm.User{} = user) do
    user = Mppm.User.get(user)
    {UserSession.from_user(user), "Hello #{user.nickname}!"}
  end



  defp get_user(conn) do
    case Plug.Conn.get_session(conn) do
      %{"current_user" => key} ->
        case Mppm.Session.AgentStore.get(key) do
          %Mppm.Session.UserSession{id: id} ->
            Mppm.Repo.get(Mppm.User, id)
          nil ->
            Plug.Conn.clear_session(conn)
            nil
        end
      _ -> nil
    end
  end

  defp get_role([]),
    do: :user
  defp get_role(roles),
    do: roles |> List.first() |> Map.get(:name) |> String.downcase() |> String.to_atom()

end
