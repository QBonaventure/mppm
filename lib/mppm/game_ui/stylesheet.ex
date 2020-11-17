defmodule Mppm.GameUI.Stylesheet do

  @widget_base_width 36

  def get_stylesheet() do
    {
      :stylesheet,
      [],
      Enum.map(get_styles(), & {:style, &1, []})}
  end

  defp get_styles() do
    [
      [class: "text", textcolor: "EEE", textsize: "0.6"],
      [class: "header-text", textcolor: "EEE", textsize: "0.8", pos: Float.to_string(@widget_base_width/2) <>" 0", halign: "center"],
      [class: "background-quad", bgcolor: "700", opacity: "0.3"],
      [class: "background-quad-black", bgcolor: "222", opacity: "0.4"]
    ]
  end

end
