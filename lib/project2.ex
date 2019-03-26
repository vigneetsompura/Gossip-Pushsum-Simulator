defmodule App do
  use Application
  def start() do
      import Supervisor.Spec, warn: false

      children = [
          worker(Registry, [:unique, :process_registry])
      ]

      opts = [strategy: :one_for_one, name: App.Supervisor]
      Supervisor.start_link(children, opts)
  end
end

defmodule Project2 do
  def run(args) do
    
    if(Enum.count(args) == 3) do
      numNodes = String.to_integer(Enum.at(args,0))
      topology = Enum.at(args,1)
      algorithm = Enum.at(args,2)

      Server.start(self(), numNodes, topology, algorithm) |> IO.inspect
    else 
      if (Enum.count(args) == 4) do
        numNodes = String.to_integer(Enum.at(args,0))
        topology = Enum.at(args,1)
        algorithm = Enum.at(args,2)
        convrate = Enum.at(args,3)
        Server.start(self(), numNodes, topology, algorithm, convrate) |>IO.inspect
      else
        IO.puts "Invalid arguments!"
      end
    end

    response()
    
  end

  defp response do
    receive do
      result -> result 
    end
  end
end

if(Enum.count(System.argv)>0) do
  Project2.run(System.argv) 
end