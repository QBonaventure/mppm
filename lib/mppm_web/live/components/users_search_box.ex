defmodule MppmWeb.Live.Component.UsersSearchBox do
  use Phoenix.LiveComponent

  def render(assigns) do
    MppmWeb.UsersListView.render("search-box.html", assigns)
  end

  def mount(socket) do
    query = Ecto.Changeset.change(%Mppm.Users.SearchQuery{})
    socket =
      socket
      |> assign(query: query)
      |> assign(results: [])

    {:ok, socket}
  end

  def handle_event("changed", %{"search_query" => %{"username" => username}}, socket) do
    changeset =
      %Mppm.Users.SearchQuery{}
      |> Ecto.Changeset.change(%{username: username})
    results =
      case username do
        "" -> []
        _username ->
          changeset
          |> Ecto.Changeset.apply_changes()
          |> Mppm.Users.SearchQuery.run()
      end

    socket =
      socket
      |> assign(query: changeset)
      |> assign(results: results)

    {:noreply, socket}
  end



end
