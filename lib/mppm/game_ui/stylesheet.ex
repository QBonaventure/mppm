defmodule Mppm.GameUI.Stylesheet do

  def get_stylesheet() do
    {
      :stylesheet,
      [],
      Enum.map(get_styles(), & {:style, &1, []})}
  end

  defp get_styles() do
    [
      [class: "text", textcolor: "EEE", textsize: "0.6"],
      [class: "header-text", textcolor: "EEE", textsize: "0.8"],
      [class: "background-quad", bgcolor: "700", opacity: "0.3"]
    ]
  end

end
