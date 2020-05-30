defmodule Clipget.Put do
  def put(data) do
    parent = self()

    Node.spawn_link(target_node(), fn ->
      send(parent, {:result, Clipget.Server.put(data)})
    end)

    receive do
      {:result, :ok} -> :ok
      {:result, other} -> raise "Unexpected result: #{inspect(other)}"
    after
      10_000 ->
        raise "Timeout waiting for clipget."
    end
  end

  defp target_node do
    [_, host] =
      node()
      |> Atom.to_string()
      |> String.split("@", parts: 2)

    ["clipget", host]
    |> Enum.join("@")
    |> String.to_atom()
  end
end
