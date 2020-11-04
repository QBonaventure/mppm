defmodule Mppm.Ruleset.RespawnBehaviour do
  use Ecto.Schema

  schema "ref_respawn_behaviours" do
    field :name, :string
    field :description, :string
  end

end
