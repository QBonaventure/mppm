defmodule MppmWeb.Live.Component.PublicTrackCard do
  use Phoenix.LiveComponent

  def preload(list_of_assigns) do
    Enum.map(list_of_assigns, fn %{id: id} ->
      track =
        Mppm.Repo.get(Mppm.Track, id)
        |> Mppm.Repo.preload([:author, time_records: [:user]])
      top_record =
        Enum.sort(track.time_records, &(&1.race_time < &2.race_time))
        |> Enum.at(0, %{})
        |> Map.get(:race_time)
      %{id: id, track: track, top_record: top_record}
    end)
  end

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    MppmWeb.ServerWebpageView.render("track.html", assigns)
  end

end
