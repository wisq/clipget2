#! /usr/bin/env elixir

defmodule Clipget.Server do
  use GenServer

  @timeout 30_000

  defmodule State do
    @enforce_keys [:put_executable, :get_executable]
    defstruct(
      put_executable: nil,
      get_executable: nil,
      put_data: nil,
      get_data: nil,
      get_port: nil
    )
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: :clipget)
  end

  def put(data) do
    GenServer.call(:clipget, {:put, data})
  end

  @impl true
  def init(nil) do
    {put, get} = detect_executables()
    status("Server started.\n")
    {:ok, %State{put_executable: put, get_executable: get}}
  end

  @impl true
  def handle_call({:put, data}, _from, state) do
    status("Received #{byte_size(data)} bytes ... ")
    put_clipboard(data, state)
    status("placed in clipboard.\n")
    {:reply, :ok, %State{state | put_data: data}, @timeout}
  end

  defp put_clipboard(data, state) do
    port = Port.open({:spawn_executable, state.put_executable}, [:binary])
    true = Port.command(port, data)
    true = Port.close(port)
  end

  @impl true
  def handle_info(:timeout, state) do
    status("Checking clipboard ... ")
    port = Port.open({:spawn_executable, state.get_executable}, [:binary, :eof])
    data = receive_all(port)
    Port.close(port)
    status("found #{byte_size(data)} bytes.\n")

    if data == state.put_data do
      status("Data matches.  Clearing clipboard ... ")
      put_clipboard("", state)
      status("done.\n")
    else
      status("Data has changed, not clearing clipboard.")
    end

    {:noreply, %State{state | put_data: nil, get_data: nil, get_port: nil}}
  end

  defp receive_all(port, buffer \\ []) do
    receive do
      {^port, {:data, data}} -> receive_all(port, [data | buffer])
      {^port, :eof} -> buffer |> Enum.reverse() |> Enum.join()
    end
  end

  defp status(text) do
    IO.write(:stdio, text)
  end

  @executables [
    ["/usr/bin/pbcopy", "/usr/bin/pbpaste"],
    ["/mnt/c/Windows/System32/clip.exe", "/mnt/c/Windows/System32/paste.exe"]
  ]

  defp detect_executables do
    case @executables |> Enum.find(&all_exist?/1) do
      [put, get] -> {put, get}
      nil -> raise "Cannot detect executables for reading and writing to clipboard"
    end
  end

  defp all_exist?(list) do
    list |> Enum.all?(fn exec -> File.exists?(exec) end)
  end
end
