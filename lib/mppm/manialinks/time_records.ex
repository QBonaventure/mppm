defmodule Mppm.Manialinks.TimeRecords do
  import Ecto.Query

  def update_table(time_records) do
    times =
      time_records
      |> Enum.sort_by(& &1.lap_time)
      |> Enum.take(10)

    base_content = [
      {:label, [text: "Local Records", pos: "10 0", textsize: "2"], []},
      {:quad, [size: "10 60", pos: "20 0", opacity: "1", colorize: "a20000000"], []},
      {:quad, [size: "50 60", opacity: "1", pos: "0 0 1", colorize: "a20000"], []},
    ]
    |> List.insert_at(1, display_lines(times))
    |> List.flatten


    table =
      {:manialink, [version: 3], [
        {
          :frame,
          [id: "local-records", pos: "-160 50", scale: "1.0"],
          base_content
      }
      ]}
      |> List.wrap
      |> :xmerl.export_simple(:xmerl_xml)
      |> List.flatten
      |> List.to_string
  end

  def display_lines(times) do
    {
      :frame,
      [id: "records-list", pos: "0 -5"],
      Enum.map_reduce(times, 0, fn time_record, acc ->
        time_record = Mppm.Repo.preload(time_record, :user)
        line =
          {:frame, [id: Integer.to_string(acc), size: "50 50", pos: "2 "<>Integer.to_string(-acc*4)], [
          {:label, [text: Mppm.TimeRecord.to_string(time_record.lap_time), textsize: "1", pos: "30 0"], []},
            {:label, [text: Integer.to_string(acc+1) <> ".", textsize: "1"], []},
            {:label, [text: time_record.user.nickname, textsize: "1", pos: "3 0"], []}
        ]}
        {line, acc+1}
      end)
      |> elem(0)
    }
  end

end
