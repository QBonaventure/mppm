defmodule MppmWeb.ServerManagerView do
  use MppmWeb, :view
  use Phoenix.LiveComponent


  def text_input(form, field, label_text) do
    content_tag :div, class: status(form, field) do
      [
        get_label(form, field, label_text),
        text_input(form, field),
        error(form, field)
      ]
    end
  end

  def select(form, field, label_text, options) do
    content_tag :div, class: status(form, field) do
      [
        get_label(form, field, label_text),
        select(form, field, options),
        error(form, field)
      ]
    end
  end




  defp get_label(form, field, label_text) do
    label form, field do
      label_text<>":"
    end
  end


  defp status(form, field) do
    case Map.has_key?(form.source.changes, field) do
      false -> "unchanged"
      true -> "changed"
    end
  end

  defp error(%Phoenix.HTML.Form{errors: errors} = form, field) do
    case Enum.find(errors, & Kernel.elem(&1,0) == field) do
      nil ->
        {:safe, []}
      _ ->
      [safe: ee] = error_tag(form, field)
      {:safe, ee}
    end
  end

end
