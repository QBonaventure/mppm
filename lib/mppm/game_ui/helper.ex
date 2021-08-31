defmodule Mppm.GameUI.Helper do
  require Logger

  @base_ui_modules ~w(Race_Chrono Race_Checkpoint Race_DisplayMessage Race_Record Race_Countdown Race_RespawnHelper Race_BestRaceViewer Rounds_SmallScoresTable Race_Record Race_ScoresTable)

  def base_ui_modules(),
    do: @base_ui_modules

  def send_to_user(manialink, server_login, user_login, timeout) do
    xml = Mppm.XML.to_doc(manialink)

    GenServer.call(
      {:global, {:broker_requester, server_login}},
      {:display_to_client_with_login, xml, user_login, false, timeout}
    )
  end

  def send_to_user(manialink, server_login, user_login) do
    xml = Mppm.XML.to_doc(manialink)

  def scale_base_ui(server_login, module, new_size) do
    GenServer.call(
      {:global, {:broker_requester, server_login}},
      {:scale_base_ui, module, new_size}
    )
  end


  def reset_base_ui(server_login, modules) do
    GenServer.call(
      {:global, {:broker_requester, server_login}},
      {:reset_base_ui, modules}
    )
  end


  def reposition_base_ui(server_login, module, {x, y}) do
    GenServer.call(
      {:global, {:broker_requester, server_login}},
      {:reposition_base_ui, module, {x, y}}
    )
  end

  def toggle_base_ui(_server_login, [], _show?) do
    :ok
  end
  def toggle_base_ui(server_login, module, show?)
  when is_binary(module) do
    toggle_base_ui(server_login, [module], show?)
  end
  def toggle_base_ui(server_login, modules, show?) do
    method =
      case show? do
        true -> :show_base_ui
        false -> :hide_base_ui
      end
    Enum.each(
      modules,
      &GenServer.call(
        {:global, {:broker_requester, server_login}},
        {method, &1}
      )
    )
  end


  def get_custom_template(server_login, player_login) do
    user = Mppm.Repo.get_by(Mppm.User, login: player_login)
    {:ok, track} = Mppm.Tracklist.get_server_current_track(server_login)
    track_records = Mppm.Repo.preload(track, :time_records) |> Map.get(:time_records)

    user_record =
      case Enum.find(track_records, & &1.user_id == user.id) do
        %Mppm.TimeRecord{} = record -> record
        _ -> Mppm.TimeRecord.get_user_track_record(track, user)
      end

    {:manialinks, [], [
      Mppm.GameUI.TimePartialsDelta.root_wrap(),
      Mppm.GameUI.BasicInfo.get_info(server_login, user),
      Mppm.GameUI.TimeRecords.get_table(track_records),
      Mppm.GameUI.TimeRecords.user_best_time(user_record),
      Mppm.GameUI.LiveRaceRanking.root_wrap(),
    ]}
  end

  def log_module_start(server_login, module_name), do:
    Logger.info "["<>server_login<>"] "<>module_name<>" started"

  def log_module_stop(server_login, module_name), do:
    Logger.info "["<>server_login<>"] "<>module_name<>" stopped"


end
