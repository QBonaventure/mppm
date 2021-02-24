defmodule Mppm.XML do

  def to_doc(data) do
    data
    |> List.wrap
    |> :xmerl.export_simple(:xmerl_xml)
    |> List.flatten
    |> List.to_string
  end

  def track_xml_to_map(data) do
    {parsed_data, _} =
      :erlang.binary_to_list(data)
      |> :xmerl_scan.string()

    header = attributes_to_map(parsed_data)

    info =
      parsed_data
      |> elem(8)
      |> Enum.at(0)
      |> attributes_to_map()
      |> Map.merge(header)

    dd =
      parsed_data
      |> elem(8)
      |> Enum.at(1)
      |> attributes_to_map()
      |> Map.merge(info)
  end

  defp attributes_to_map(data) do
    data
    |> elem(7)
    |> Enum.map(& {elem(&1, 1), List.to_string(elem(&1, 8))})
    |> Map.new()
  end

end
