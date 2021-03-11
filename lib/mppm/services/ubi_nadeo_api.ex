defmodule Mppm.Service.UbiNadeoApi do
  alias HTTPoison.Response
  use HTTPoison.Base

  @host Application.get_env(:mppm, :ubi_nadeo_api, :host) |> Keyword.get(:host)

  @enforce_keys [:version, :release_datetime, :download_link, :status]
  defstruct [:version, :release_datetime, :download_link, status: :unknown]
  @type t :: %__MODULE__{
      version: integer(),
      release_datetime: DateTime.t(),
      download_link: binary(),
      status: atom(),
  }


  @spec get_user_info(String.t()) :: {:ok, Mppm.User.t()} | {:error, any()}
  def get_user_info(uuid) do
    get("/users/#{uuid}/username")
    |> case do
      {:ok, %{"username" => username, "login" => login, "uuid" => uuid}} ->
        {:ok, Mppm.User.new(uuid, login, username)}
      {:ok, %{code: _code, message: _msg}} = error ->
        error
    end
  end

  @spec latest_server_version() :: map()
  def latest_server_version(),
    do: get("/servers/latest_version_info")

  @spec server_versions() :: [map()]
  def server_versions(),
    do: get("/servers/list")


  @doc """
  Overrides default `HTTPoison.Base` implementation
  """
  @spec process_url(String.t()) :: String.t()
  def process_url(url),
   do: @host<>url


  @spec process_response_body(String.t()) :: {:ok, map()} | {:error, map()}
  def process_response_body(body) do
    case Jason.decode(body) do
      {:ok, %{"data" => data}} ->
        data
      {:ok, %{"code" => code, "error" => error_message}} when code != 200 ->
        %{code: code, message: error_message}
    end
  end

  @doc """
  Overrides default HTTPoison.Base implementation
  """
  @spec process_response(HTTPoison.Response.t()) :: map()
  def process_response(%Response{} = response),
    do: response.body

end
