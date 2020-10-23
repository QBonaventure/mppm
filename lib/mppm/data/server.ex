defmodule Mppm.Server do
  use Ecto.Schema

  schema "game_servers" do
    has_one :tracklist, Mppm.Tracklist
  end

end
