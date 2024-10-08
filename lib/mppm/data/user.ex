defmodule Mppm.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias __MODULE__
  alias Mppm.Service.UbiNadeoApi


  @nadeo_user_nickname "Nadeo"

  schema "users" do
    field :login, :string
    field :nickname, :string
    field :uuid, Ecto.UUID, autogenerate: false
    has_many :roles, Mppm.Relationship.UsersRoles, on_replace: :delete
    many_to_many :app_roles, Mppm.UserAppRole, join_through: "rel_users_app_roles", on_replace: :delete
  end


  def new(uuid, login, nickname), do:
    %Mppm.User{uuid: uuid, login: login, nickname: nickname}


  def new_changeset(%User{} = user, %{uuid: uuid, nickname: _nickname} = data)
  when not is_nil(uuid) do
    data = Map.put(data, :login, uuid_to_login(uuid))
    user
    |> cast(data, [:login, :nickname, :uuid])
    |> validate_required([:login, :nickname, :uuid])
  end

  def new_changeset(%User{} = user, %{login: login, nickname: _nickname} = data)
  when not is_nil(login) do
    data = Map.put(data, :uuid, login_to_uuid(login))
    user
    |> cast(data, [:login, :nickname, :uuid])
    |> validate_required([:login, :nickname, :uuid])
  end



  def changeset(%User{} = user, data \\ []) do
    user
    |> cast(data, [:login, :nickname, :uuid])
  end


  def remove_role(%User{} = user, %Mppm.GameServer.Server{} = server, %Mppm.UserRole{} = role) do
    user = update_role(user, server, Enum.reject(user.roles, & &1.user_role.id == role.id))
    Phoenix.PubSub.broadcast(Mppm.PubSub, "players-status", {:role_removed, elem(user, 1), role})
    user
  end

  def add_role(%User{} = user, %Mppm.GameServer.Server{} = server, %Mppm.UserRole{} = role) do
    role = %Mppm.Relationship.UsersRoles{user_role: role, server: server}
    user = update_role(user, server, user.roles ++ [role])
    Phoenix.PubSub.broadcast(Mppm.PubSub, "players-status", {:role_granted, elem(user, 1), role})
    user
  end

  defp update_role(%User{} = user, _server, roles) do
    user
    |> change()
    |> put_assoc(:roles, roles)
    |> Mppm.Repo.update()
  end

  def update_app_role(%Mppm.User{app_roles: %Ecto.Association.NotLoaded{}} = user, role),
    do: Mppm.Repo.preload(user, [:app_roles]) |> update_app_role(role)
  def update_app_role(%Mppm.User{} = user, []) do
    user
    |> Ecto.Changeset.change(%{app_roles: []})
    |> Mppm.Repo.update()
  end
  def update_app_role(%Mppm.User{} = user, %Mppm.UserAppRole{} = role) do
    user
    |> Ecto.Changeset.change(%{app_roles: [role]})
    |> Mppm.Repo.update()
  end


  @doc """
    Returns full %Mppm.User{} structure from database. The user will be created
    if it doesn't exist yet.

    Returns `%Mppm.User{}`
  """
  def get(%Mppm.User{uuid: uuid} = user) when not is_nil(uuid), do:
    build_query_with_uuid(user) |> fetch_or_create(user)
  def get(%Mppm.User{login: login} = user) when not is_nil(login), do:
    build_query_with_login(user) |> fetch_or_create(user)


  def get_nadeo_user() do
    Mppm.Repo.one(from u in Mppm.User, where: u.nickname == @nadeo_user_nickname)
  end

  @doc """
    Encodes user UUID to base 64 URL safe user login as used in-game.

    Returns :string

    ### Examples
      iex> Mppm.User.uuid_to_login("e454aa5d-ce99-4b89-8115-329313cad636")
      "5FSqXc6ZS4mBFTKTE8rWNg"
  """
  def uuid_to_login(uuid) do
    uuid
    |> Ecto.UUID.dump
    |> Kernel.elem(1)
    |> Base.url_encode64()
    |> String.replace_trailing("=", "")
  end

  @doc """
    Encodes base 64 URL safe user login as used in-game to user UUID.

    Returns Ecto.UUID.t() :: <<_::288>>

    ### Examples
      iex> Mppm.User.login_to_uuid("5FSqXc6ZS4mBFTKTE8rWNg")
      "e454aa5d-ce99-4b89-8115-329313cad636"
  """
  def login_to_uuid(login) do
    login
    |> String.pad_trailing(24, "=")
    |> Base.url_decode64!()
    |> Ecto.UUID.cast!
  end


  def check_install() do
    case Mppm.Repo.one(from u in User, where: u.nickname == @nadeo_user_nickname) do
      nil ->
        uuid = Ecto.UUID.generate()
        new(uuid, uuid_to_login(uuid), @nadeo_user_nickname)
        |> create_new_user()
      _ ->
      :ok
    end
  end



  ##############################################################################
  ############################# Private Functions ##############################
  ##############################################################################

  defp fetch_or_create(query, user) do
    # Logins are 22 bytes long. if it's not, it's a fake player.
    case user.login != nil and byte_size(user.login) != 22 do
      false ->
        case Mppm.Repo.one(query) |> exists?() do
          {:found, user} -> user
          {:not_found, _} ->
          create_new_user(user)
        end
      true ->
        Map.put(user, :is_fake, true)
    end
  end

  defp create_new_user(%User{login: nil, uuid: uuid} = user)
  when is_binary(uuid), do:
    user |> Map.put(:login, uuid_to_login(uuid)) |> create_new_user()
  defp create_new_user(%User{login: login, uuid: nil} = user)
  when is_binary(login), do:
    user |> Map.put(:uuid, login_to_uuid(login)) |> create_new_user()
  defp create_new_user(%User{nickname: nil} = user) do
    case UbiNadeoApi.get_user_info(user.uuid) do
      {:ok, user} ->
        create_new_user(user)
      {:error, %{message: message}} ->
        {:error, message}
    end
  end

  defp create_new_user(%User{} = user) do
    %User{}
    |> User.new_changeset(Map.from_struct(user))
    |> Mppm.Repo.insert!
  end


  defp build_query_with_uuid(%User{uuid: uuid}), do:
    from u in User, where: u.uuid == ^uuid

  defp build_query_with_login(%User{login: login}), do:
    from u in User, where: u.login == ^login

  defp exists?(nil), do: {:not_found, nil}
  defp exists?(%User{} = user), do: {:found, user}


end
