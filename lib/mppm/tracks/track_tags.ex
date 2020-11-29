defmodule Mppm.TrackTag do
  @moduledoc """
  UserProject module
  """
  use Ecto.Schema
  import Ecto.Changeset

  @already_exists "ALREADY_EXISTS"

  @primary_key false
  schema "rel_tracks_tags" do
    belongs_to(:tracks, Mppm.Track, foreign_key: :track_id, primary_key: true)
    belongs_to(:ref_track_styles, Mppm.TrackStyle, foreign_key: :style_id, primary_key: true)
  end

  @required_fields ~w(track_id style_id)a
  def changeset(track_tag, params \\ %{}) do
    track_tag
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:track_id)
    |> foreign_key_constraint(:style_id)
    |> unique_constraint([:tracks, :ref_track_styles],
      name: :uk_tracks_tags,
      message: @already_exists
    )
  end
end
