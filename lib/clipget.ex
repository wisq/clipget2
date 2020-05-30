defmodule Clipget do
  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :rest_for_one, name: Clipget.Supervisor]
    Supervisor.start_link(child_list(), opts)
  end

  defp child_list do
    if server?() do
      [Clipget.Server]
    else
      []
    end
  end

  defp server? do
    node()
    |> Atom.to_string()
    |> String.starts_with?("clipget@")
  end
end
