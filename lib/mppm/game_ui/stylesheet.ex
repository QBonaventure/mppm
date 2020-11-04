defmodule Mppm.GameUI.Stylesheet do

  def get_stylesheet() do
    {
      :stylesheet,
      [],
      Enum.map(get_styles(), & {:style, &1, []})}
  end

  defp get_styles() do
    [
      [class: "text", textcolor: "EEE", textsize: "1"],
      [class: "header-text", textcolor: "EEE", textsize: "2"],
      [class: "background-quad", bgcolor: "222", opacity: "0.3"]
    ]
  end

end
