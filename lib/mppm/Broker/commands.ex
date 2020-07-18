defmodule Mppm.Broker.Commands do
  alias Mppm.Broker

  @methods %{
    :list_methods => "system.listMethods",
    :get_version => "GetVersion",
    :get_max_players => "GetMaxPlayers",
    :get_status => "GetStatus",
    :get_chat => "GetChatLines",
    :get_sys_info => "GetSystemInfo"
  }

  @methods_with_params %{
    :enable_callbacks => "EnableCallbacks"
  }


  def handle_call({:query, :enable_callbacks}, _, state) do
    res = Broker.make_request("EnableCallbacks", [true], state.socket)
    {:reply, res, state}
  end


  def handle_call({:query, method}, _, state)  do
    res = Broker.make_request(@methods[method], [], state.socket)
    {:reply, res, state}
  end


  def handle_call({:query, method, params}, _, state) do
    res = Broker.make_request(@methods[method], params, state.socket)
    {:reply, res, state}
  end


  def build_query(method, params, req_id) do
    query =
      %XMLRPC.MethodCall{method_name: method, params: params}
      |> XMLRPC.encode!
    <<byte_size(query)::little-32>> <> req_id <> query
  end


  # def get_request_id(state) do
  #   new_id = state.request_id + 1
  #   {new_id, <<new_id::little-32>>}
  # end

end
