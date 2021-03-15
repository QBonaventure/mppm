defmodule Mppm.XML do


  def from_file(filepath) do
    {result, _misc} = filepath |> :xmerl_scan.file([{:space, :normalize}])
    [clean] = :xmerl_lib.remove_whitespace([result])
    :xmerl_lib.simplify_element(clean)
  end


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

    parsed_data
    |> elem(8)
    |> Enum.at(1)
    |> attributes_to_map()
    |> Map.merge(info)
  end


  def script_setting_value_correction(true), do: 1
  def script_setting_value_correction(false), do: 0
  def script_setting_value_correction(value), do: value


  def get_type(value) when is_boolean(value), do: "boolean"
  def get_type(value) when is_integer(value), do: "integer"
  def get_type(value) when is_binary(value), do: "text"

  def charlist(value) when is_binary(value), do: String.to_charlist(value)
  def charlist(value) when is_integer(value), do: Integer.to_string(value) |> String.to_charlist
  def charlist(%Postgrex.INET{} = value), do: charlist(EctoNetwork.INET.decode(value))
  def charlist(true), do: ['True']
  def charlist(false), do: ['False']
  def charlist(nil = _value), do: []


  defp attributes_to_map(data) do
    data
    |> elem(7)
    |> Enum.map(& {elem(&1, 1), List.to_string(elem(&1, 8))})
    |> Map.new()
  end

end
