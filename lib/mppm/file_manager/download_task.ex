defmodule Mppm.FileManager.DownloadTask do
  use GenServer, restart: :temporary
  require Logger


  def handle_info(%HTTPoison.AsyncStatus{code: 200}, state) do
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncHeaders{headers: headers}, state) do
    {"Content-Length", file_size} = Enum.find(headers, & elem(&1, 0) == "Content-Length")
    {:noreply, %{state | file_size: String.to_integer(file_size)}}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, state) do
    IO.binwrite(state.file_pid, chunk)
    {:noreply, %{state | downloaded: state.downloaded + byte_size(chunk)}}
  end

  def handle_info(%HTTPoison.AsyncEnd{}, state) do
    {:stop, :normal, state}
  end


  def terminate(:normal, state) do
    cleanup(state)
    if state.callback do
      {fun, args} = state.callback
      spawn(fn -> fun.(state.file_destination, args) end)
    end
    Mppm.Notifications.notify(:info, download_success_msg(state.file_destination))
  end

  def terminate(_reason, state) do
    cleanup(state)
    Mppm.Notifications.notify(:info, download_failure_msg(state.file_destination))
  end


  defp download_success_msg(filepath),
    do: "Download of file \"#{filepath}\" complete!"

  defp download_failure_msg(filepath),
    do: "Download of file \"#{filepath}\" failed!"

  defp cleanup(file_pid),
    do: File.close(file_pid)


  def child_spec(file_url, file_destination, callback \\ nil) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [file_url, file_destination, callback]},
      restart: :temporary
    }
  end

  def start_link(file_url, file_destination, callback), do:
    GenServer.start_link(__MODULE__, [file_url, file_destination, callback])

  def init([file_url, file_destination, callback]) do
    {:ok, pid} = File.open(file_destination, [:write, :binary])
    {:ok, %HTTPoison.AsyncResponse{id: ref}} = HTTPoison.get(file_url, %{}, stream_to: self())

    {:ok, %{file_pid: pid, file_destination: file_destination, ref: ref, file_size: 0, downloaded: 0, callback: callback}}
  end
end
