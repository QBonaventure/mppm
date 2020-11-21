defmodule Mppm.Session.UserSession do
  alias __MODULE__
  alias Mppm.Repo
  alias Mppm.Session.AgentStore
  alias Ecto.Changeset
  import Ecto.Query
  import Plug.Conn

  defstruct [
    key: nil,
    id: nil,
    nickname: nil,
    uuid: nil,
    component_pid: nil
  ]

  def current_user(conn), do: conn.assigns[:current_user]
  def logged_in?(conn), do: !!current_user(conn)

  def init(opts \\ []) do
    %{error: opts[:error] || "Not authorized"}
  end

  def call(conn, opts\\ []) do
    if user = get_user(conn) do
      assign(conn, :current_user, user)
    else
      conn
      |> Phoenix.Controller.redirect(to: "/auth/login.html")
      |> halt()
    end
  end


  def from_user(%Mppm.User{id: id, nickname: nickname, uuid: uuid}) do
    %UserSession{
      key: :crypto.strong_rand_bytes(18) |> Base.url_encode64,
      id: id,
      nickname: nickname,
      uuid: uuid
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


  @spec set_user_session(%Plug.Conn{}, %Mppm.User{}) :: {%Plug.Conn{}, String.t}
  def set_user_session(conn, %Mppm.User{} = user) do
      {user_session, message} = create_user_session(user)

      AgentStore.create(user_session)
      conn = put_session(conn, :current_user, user_session.key)

      {conn, message}
  end


  @spec create_user_session(%Mppm.User{}) :: {%UserSession{}, String.t}
  defp create_user_session(%Mppm.User{} = user) do
    {user_session, message} =
      case Mppm.User.find(user) do
        {:unfound, nil} ->
          {:ok, created_user} =
            %Mppm.User{}
            |> User.registration_changeset(%{nickname: user.nickname, uuid: user.uuid})
            |> Repo.insert
          {UserSession.from_user(created_user), greet(created_user)}
        {:found, loaded_user} ->
          loaded_user =
            case is_nil(loaded_user.uuid) do
              true ->
                {:ok, loaded_user} =
                  loaded_user
                  |> Mppm.User.changeset(%{uuid: user.uuid})
                  |> Mppm.Repo.update
              false ->
                loaded_user
            end
          {UserSession.from_user(loaded_user), greet(loaded_user)}
      end
  end


  defp greet(%Mppm.User{nickname: nickname}), do: "Hello #{nickname}! Looks like it's your first connection."
  defp greet(%UserSession{nickname: nickname}), do: "Welcome back #{nickname}!"



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

end
