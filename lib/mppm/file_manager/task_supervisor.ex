defmodule Mppm.FileManager.TasksSupervisor do
  use DynamicSupervisor


  def download_file(file_url, file_destination, {fun, attrs} = callback) do
    spec = Mppm.FileManager.DownloadTask.child_spec(file_url, file_destination, callback)
    DynamicSupervisor.start_child(__MODULE__, spec)
  end



  def start_link(_arg), do:
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)

  def init(:ok), do:
    DynamicSupervisor.init(strategy: :one_for_one)

  def start_child(%{id: Mppm.FileManager.DownloadTask} = downloader_spec) do
    {:ok, _child_pid} = DynamicSupervisor.start_child(__MODULE__, downloader_spec)
  end

end
