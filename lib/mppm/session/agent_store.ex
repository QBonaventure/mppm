defmodule Mppm.Session.AgentStore do
  alias Mppm.Session.UserSession

  def create(%UserSession{key: key, id: _id} = args) do
    Agent.start_link(fn -> args end, name: {:global, {:session, key}})
  end

  def get(%{"current_user" => %Mppm.Session.UserSession{key: key}}) do
    case :global.whereis_name({:session, key}) do
      :undefined -> nil
      _pid -> Agent.get({:global, {:session, key}}, & &1)
    end
  end

  def get(key) do
    case :global.whereis_name({:session, key}) do
      :undefined -> nil
      _pid -> Agent.get({:global, {:session, key}}, & &1)
    end
  end

  def update(key, %UserSession{} = new_state) do
    case :global.whereis_name({:session, key}) do
      :undefined -> nil
      _pid -> Agent.update({:global, {:session, key}}, fn _old_state -> new_state end)
    end
  end

end
