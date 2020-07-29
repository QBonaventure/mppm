defmodule Mppm.Service.ManiaExchange do

  def get_last_maps() do
    request = %HTTPoison.Request{
      method: :get,
      url: "https://trackmania.exchange/mapsearch2/search?api=on&author=dedejo",
      headers: [{"Accept", "application/json"}]
    }

    {:ok, res} = HTTPoison.request(request)
    res
    |> Map.get(:body)
    |> Jason.decode!
    |> Map.get("results")
    |> List.first
  end



end
