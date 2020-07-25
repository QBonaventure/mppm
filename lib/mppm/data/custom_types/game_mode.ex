defmodule Mppm.Type.GameMode do
  use Ecto.Schema

  schema "game_modes" do
    field :name, :string
    field :script_name, :string
  end

end
