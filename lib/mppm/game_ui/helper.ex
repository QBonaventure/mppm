defmodule Mppm.GameUI.Helper do


  def send_to_user(manialink, server_login, user_login) do
    xml = Mppm.XML.to_doc(manialink)

    GenServer.call(
      {:global, {:mp_broker, server_login}},
      {:display_to_client_with_login, xml, user_login, false, 0}
    )
  end

  def send_to_all(manialink, server_login) do
    xml = Mppm.XML.to_doc(manialink)
    GenServer.call({:global, {:mp_broker, server_login}}, {:display, xml, false, 0})
  end



  def get_custom_template(server_login, player_login) do
    user = Mppm.Repo.get_by(Mppm.User, login: player_login)
    track = GenServer.call(Mppm.TimeTracker, {:get_server_current_track, server_login})
    track_records = Mppm.Repo.preload(track, :time_records) |> Map.get(:time_records)

    user_record =
      case Enum.find(track_records, & &1.user_id == user.id) do
        %Mppm.TimeRecord{} = record -> record
        _ -> Mppm.TimeRecord.get_user_track_record(track, user)
      end

    {:manialinks, [], [
        Mppm.GameUI.TimeRecords.get_table(track_records),
        Mppm.GameUI.TimeRecords.user_best_time(user_record),
    ]}
  end


  def get_empty_template(), do:
    {:manialinks, [], [
      {:manialink, [], [
        Mppm.GameUI.Stylesheet.get_stylesheet,
        Mppm.GameUI.TimeRecords.get_local_records_root(),
        Mppm.GameUI.TimeRecords.get_user_best_time_root(),
      ]}
    ]}
end
