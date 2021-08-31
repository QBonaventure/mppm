defmodule Mppm.GameUI.Module do
  @doc """
  Manages dsplays to the players' UI.
  """

  @doc """
  The module name to be display in the UI or CLI.
  """
  @callback name() :: String.t


end
