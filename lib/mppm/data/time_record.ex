defmodule Mppm.TimeRecord do
  use GenServer
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset


  @primary_key false
  schema "time_records" do
    belongs_to :track, Mppm.Track, foreign_key: :track_id, primary_key: true
    belongs_to :user, Mppm.User, foreign_key: :user_id, primary_key: true
    field :checkpoints, {:array, :integer}, default: []
    field :lap_time, :integer
    field :race_time, :integer
  end

  def changeset(%Mppm.TimeRecord{} = time_record, params \\ %{}) do
    time_record
    |> cast(params, [:checkpoints, :lap_time, :race_time, :track_id, :user_id])
  end


  def insert_new_time(%Mppm.Track{} = track, %Mppm.User{} = user, time, checkpoints) do
    params = %{checkpoints: checkpoints, race_time: time, lap_time: time, track_id: track.id, user_id: user.id}
    %Mppm.TimeRecord{}
    |> Mppm.TimeRecord.changeset(params)
    |> Mppm.Repo.insert!(on_conflict: {:replace_all_except, [:user_id, :track_id]}, conflict_target: [:user_id, :track_id])
  end

  def get_user_track_record(%Mppm.Track{} = track, %Mppm.User{} = user), do:
    Mppm.Repo.one(from r in Mppm.TimeRecord, where: r.track_id == ^track.id and r.user_id == ^user.id)

  def get_track_records(track_uid) do
    Mppm.Repo.get_by(Mppm.Track, track_uid: track_uid)
    |> Mppm.Repo.preload(time_records: [:user])
    |> Map.get(:time_records)
  end


  def compare(time_a, nil), do:
    :missing_time

  def compare(%Mppm.TimeRecord{lap_time: time_a}, %Mppm.TimeRecord{lap_time: time_b}), do:
    compare(time_a, time_b)

  def compare(time_a, time_b) do
    case time_a - time_b do
      _diff when _diff < 0 -> :ahead
      _diff when _diff > 0 -> :behind
      0 -> :equal
    end
  end


  def get_sign(time) when is_integer(time) do
    case time < 0 do
      true -> "-"
      false -> "+"
    end
  end

  def to_string(time) when is_integer(time) do
    [sec, ms] =
      time
      |> Kernel.abs
      |> Integer.digits
      |> Enum.split(-3)
      |> Tuple.to_list
      |> Enum.map(& Integer.undigits(&1))

    min = Integer.floor_div(sec, 60)
    sec = rem(sec, 60)

    case min do
      0 -> string_second(sec) <> "." <> string_millisecond(ms)
      _ -> string_minute(min) <> ":" <> string_second(sec) <> "." <> string_millisecond(ms)
    end
  end

  defp string_millisecond(ms) when is_integer(ms), do: Integer.to_string(ms) |> String.pad_leading(3, "0")
  defp string_second(sec) when is_integer(sec), do: Integer.to_string(sec) |> String.pad_leading(2, "0")
  defp string_minute(min) when is_integer(min), do: Integer.to_string(min)


end
