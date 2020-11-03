defmodule Mppm.XML do

  def to_doc(data) do
    data
    |> List.wrap
    |> :xmerl.export_simple(:xmerl_xml)
    |> List.flatten
    |> List.to_string
  end

end
