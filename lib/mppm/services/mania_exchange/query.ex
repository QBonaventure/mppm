defmodule Mppm.Service.ManiaExchange.Query do
  import Ecto.Changeset
  use Ecto.Schema
  alias __MODULE__


  embedded_schema do
    field :author_name, :string
    belongs_to :track_style, Mppm.TrackStyle, foreign_key: :track_style_id
    field :map_name, :string, default: ""
    field :page, :integer, default: 1
    field :items_per_page, :integer, default: 20
    field :mode, :integer, default: 0
  end

  def changeset(%Query{} = query, options \\ %{}) do
    query
    |> cast(options, [:author_name, :track_style_id, :map_name, :page, :items_per_page])
  end

  def latest_awarded_maps() do
    %Query{mode: 4, items_per_page: 10}
  end

end
