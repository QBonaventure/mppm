defmodule Mppm.FileManager.DownloadTask do
  use GenServer, restart: :temporary
  require Logger


  def handle_info(%HTTPoison.AsyncStatus{code: 200} = ss, state) do
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncHeaders{headers: headers} = dsf, state) do
    {"Content-Length", file_size} = Enum.find(headers, & elem(&1, 0) == "Content-Length")
    {:noreply, %{state | file_size: String.to_integer(file_size)}}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk} = qq, state) do
    IO.binwrite(state.file_pid, chunk)
    {:noreply, %{state | downloaded: state.downloaded + byte_size(chunk)}}
  end

  def handle_info(%HTTPoison.AsyncEnd{}, state) do
    File.close(state.file_pid)

    if state.callback do
      {fun, args} = state.callback
      spawn(fn -> fun.(state.file_destination, args) end)
    end

    {:stop, :job_complete, state}
  end



  def child_spec(file_url, file_destination, callback) do
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
