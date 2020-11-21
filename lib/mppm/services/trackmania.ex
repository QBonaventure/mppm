defmodule Mppm.Service.Trackmania do
  use OAuth2.Strategy
  alias __MODULE__
  import Application, only: [get_env: 2]

  @internal_server_error_message "Nadeo OAuth endpoint down"

  def client do
    OAuth2.Client.new([
      strategy: __MODULE__,
      client_id: get_env(:mppm, Trackmania)[:client_id],
      client_secret: get_env(:mppm, Trackmania)[:client_secret],
      redirect_uri: get_env(:mppm, Trackmania)[:redirect_uri],
      authorize_url: get_env(:mppm, Trackmania)[:authorize_url],
      token_url: get_env(:mppm, Trackmania)[:token_url],
      site: get_env(:mppm, Trackmania)[:site],
      response_type: get_env(:mppm, Trackmania)[:response_type]
    ])
    |> OAuth2.Client.put_serializer("application/json", Jason)
  end

  def authorize_url do
    OAuth2.Client.authorize_url!(client(), scope: "", state: "sssdd")
  end

  def get_token!(params \\ [], headers \\ [], opts \\ []) do
    OAuth2.Client.get_token!(client(), params, headers, opts)
  end


  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_header("accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end

  def get_user(%{access_token: token}) do
    IO.inspect token
    "https://api.trackmania.com/api/user"
    |> HTTPoison.get(get_user_request_headers(token))
    |> parse_user_response()
    |> resolve_user_response()
  end



  defp parse_user_response({:ok, %HTTPoison.Response{status_code: 500}}), do:
    {:error, @internal_server_error_message}

  defp parse_user_response({:ok, %HTTPoison.Response{status_code: 200, body: raw_body}}), do:
    {:ok, raw_body}

  defp parse_user_response({:error, %{reason: reason}}), do:
   {:error, reason}


  defp resolve_user_response({:error, reason}), do:
    {:error, reason}

  defp resolve_user_response({:ok, body}) do
    %{"account_id" => uuid, "display_name" => nickname} = body |> Jason.decode!
    {:ok, %Mppm.User{nickname: nickname, uuid: uuid}}
  end


  defp get_user_request_headers(token), do:
    [
      {:"Authorization", "Bearer #{token}"},
      {:"Content-Type", "application/json"}
    ]

end
