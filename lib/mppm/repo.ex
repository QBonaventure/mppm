defmodule Mppm.Repo do
  use Ecto.Repo,
    otp_app: :mppm,
    adapter: Ecto.Adapters.Postgres

  @spec unload(struct(), [atom(), ...]) :: struct()
  def unload(%_{__meta__: _} = record, fields) do
    Enum.reduce(
      fields,
      record,
      &(Map.put(&2, &1, %Ecto.Association.NotLoaded{__field__: &1}))
      )
  end

end
