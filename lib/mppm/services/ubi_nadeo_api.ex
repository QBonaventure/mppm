defmodule Mppm.Service.UbiNadeoApi do
  alias HTTPoison.Response

  @host Application.get_env(:mppm, :ubi_nadeo_api, :host) |> Keyword.get(:host)

  @enforce_keys [:version, :release_datetime, :download_link, :status]
  defstruct [:version, :release_datetime, :download_link, status: :unknown]
  @type t :: %__MODULE__{
      version: integer(),
      release_datetime: DateTime.t(),
      download_link: binary(),
      status: atom(),
  }

  def get_user_info(uuid) do
    "#{@host}/users/#{uuid}/username"
    |> HTTPoison.get()
    |> process_response()
    |> case do
      {:ok, %{"username" => username, "login" => login, "uuid" => uuid}} ->
        {:ok, Mppm.User.new(uuid, login, username)}
      error ->
        error
    end
  end

  def latest_server_version() do
    "#{@host}/servers/latest_version_info"
    |> HTTPoison.get()
    |> process_response()
  end

  def server_versions() do
    "#{@host}/servers/list"
    |> HTTPoison.get()
    |> process_response()
  end

  defp process_response({:ok, %Response{status_code: 200, body: body}}) do
    body
    |> Jason.decode!
    |> format_payload()
  end

  defp process_response({:ok, %Response{status_code: 400, body: body}}) do
    body
    |> Jason.decode!
    |> format_payload()
  end

  defp format_payload(%{"data" => data}), do:
    {:ok, data}
  defp format_payload(%{"code" => code, "error" => error_message})
  when code != 200, do:
    {:error, %{code: code, message: error_message}}


end
