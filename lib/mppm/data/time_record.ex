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
    IO.inspect params
    time_record
    |> cast(params, [:checkpoints, :lap_time, :race_time, :track_id, :user_id])
  end


  def to_string(time) when is_integer(time) do
    [sec, ms] =
      time
      |> Integer.digits
      |> Enum.split(-3)
      |> Tuple.to_list
      |> Enum.map(& Integer.undigits(&1))

    min = Integer.floor_div(sec, 60)
    sec = rem(sec, 60)

    case min do
      0 -> Integer.to_string(sec)<>"."<>Integer.to_string(ms)
      _ -> Integer.to_string(min)<>":"<>String.pad_leading(Integer.to_string(sec), 2, "0")<>"."<>Integer.to_string(ms)
    end
  end


end
