#! /usr/bin/env elixir

defmodule Clipget.Server do
  use GenServer

  @timeout 30_000

  defmodule State do
    @enforce_keys [:put_command, :get_command]
    defstruct(
      put_command: nil,
      get_command: nil,
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
    {put, get} = detect_commands()
    status("Server started.\n")
    {:ok, %State{put_command: put, get_command: get}}
  end

  @impl true
  def handle_call({:put, data}, _from, state) do
    status("Received #{byte_size(data)} bytes ... ")
    put_clipboard(data, state)
    status("placed in clipboard.\n")
    {:reply, :ok, %State{state | put_data: data}, @timeout}
  end

  defp put_clipboard(data, state) do
    port = Port.open({:spawn, state.put_command}, [:binary])
    true = Port.command(port, data)
    true = Port.close(port)
  end

  @impl true
  def handle_info(:timeout, state) do
    status("Checking clipboard ... ")
    port = Port.open({:spawn, state.get_command}, [:binary, :eof])
    data = receive_all(port)
    Port.close(port)
    status("found #{byte_size(data)} bytes.\n")

    if strip(data) == strip(state.put_data) do
      status("Data matches.  Clearing clipboard ... ")
      put_clipboard("", state)
      status("done.\n")
    else
      status("Data has changed, not clearing clipboard.\n")
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

  @commands [
    {:MacOS, ["pbcopy", "pbpaste"], ["", ""]},
    {:WSL, ["clip.exe", "powershell.exe"], ["", " -command Get-Clipboard"]}
  ]

  defp detect_commands do
    case @commands |> Enum.find_value(&find_commands/1) do
      {put, get} -> {put, get}
      nil -> raise "Cannot detect executables for reading and writing to clipboard"
    end
  end

  defp find_commands({os, [put_base, get_base], [put_args, get_args]}) do
    put_exec = System.find_executable(put_base)
    get_exec = System.find_executable(get_base)

    if put_exec && get_exec do
      status("Using #{os} executables: #{put_exec}, #{get_exec}\n")
      {put_exec <> put_args, get_exec <> get_args}
    else
      nil
    end
  end

  defp strip(str) do
    str
    |> String.replace("\r", "")
    |> String.trim()
  end
end
