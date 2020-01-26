defmodule Mppm.ServersCache do
  use GenServer

  def token?(token_id) do
    GenServer.call(__MODULE__, {:token?, token_id})
  end


  def set_new_token(token, claims) do
    GenServer.cast(__MODULE__, {:set_new_token, token, claims})
  end


  def handle_cast({:set_new_token, token, token_id}, state) do
    true = :ets.insert(:token_cache, {token_id, token})
    {:noreply, state}
  end


  def handle_call({:token?, token_id}, _, _) do
    case :ets.lookup(:token_cache, token_id) do
      {:found, _} -> true
      {:not_found, _} -> false
    end
  end


  def start_link _opts \\ [] do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end


  def init _ do
    :ets.new(:token_cache, [:set, :public, :named_table, read_concurrency: true])
    {:ok, nil}
  end

end
