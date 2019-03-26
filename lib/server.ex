

defmodule Server do
    use GenServer

    def start(main, numNodes, topology, algorithm) do
        App.start()
        state = %{ :main => main, :numNodes => numNodes, :topology => topology, :algorithm=> algorithm, :conv => 0, :reach =>0, :died => 0, :convrate => 0.9}
        GenServer.start_link(__MODULE__, state, name: via_tuple("server"))
    end

    def start(main, numNodes, topology, algorithm, convrate) do
        App.start()
        state = %{:main => main, :numNodes => numNodes, :topology => topology, :algorithm=> algorithm, :conv => 0, :reach =>0, :died => 0, :convrate => convrate}
        GenServer.start_link(__MODULE__, state, name: via_tuple("server"))
    end

    def init(state) do
        
        numNodes = state[:numNodes]
        topology = state[:topology]
        algorithm = state[:algorithm]
        case algorithm do
            "gossip" ->
                case topology do
                    "full"->
                        for n <- 0..numNodes-1 do
                            wState = %{:server => via_tuple("server"),:id => n,:state => "initial" , :count => 0, :msg => "", :neighbors => Enum.reject(0..numNodes-1, fn(x)-> x==n end)}
                            Worker.start(n, wState)
                        end
                        GenServer.cast(via_tuple(Enum.random(0..numNodes-1)), {:rumor, "Message"}) 
                    "line"->
                        for n <- 0..numNodes-1 do
                            wState = %{:server => via_tuple("server"),:id => n,:state => "initial" , :count => 0, :msg => "", :neighbors => Enum.reject([n-1,n+1], fn(x)-> (x==-1 || x == numNodes) end)}
                            Worker.start(n, wState)
                        end
                        GenServer.cast(via_tuple(Enum.random(0..numNodes-1)), {:rumor, "Message"})
                    "3D"->
                        num = round(:math.pow(numNodes, 1/3))
                        GenServer.cast(self(), {:set_nodes, num*num*num})
                        for i <- 0..num-1 do
                            for j <- 0..num-1 do
                                for k <- 0..num-1 do
                                    neighbors = Enum.reject([[i-1,j,k],[i+1,j,k],[i,j-1,k],[i,j+1,k],[i,j,k-1],[i,j,k+1]], fn([x,y,z]) -> (x==-1||y==-1||z==-1||x==num||y==num||z==num) end)
                                    wState = %{:server => via_tuple("server"),:id => [i,j,k],:state => "initial" , :count => 0, :msg => "", :neighbors => neighbors}
                                    Worker.start([i,j,k], wState)
                                end
                            end
                        end
                        GenServer.cast(via_tuple([Enum.random(0..num-1),Enum.random(0..num-1),Enum.random(0..num-1)]), {:rumor, "Message"})
                    "sphere" ->
                        num = round(:math.pow(numNodes,1/2))
                        GenServer.cast(self(), {:set_nodes, num*num})
                        for i <- 0..num-1 do
                            for j <- 0..num-1 do
                                neighbors = [[rem(num+i-1,num),j],[rem(num+i+1,num),j],[i,rem(num+j-1,num)],[i,rem(num+j+1,num)]]
                                wState = %{:server => via_tuple("server"),:id => [i,j],:state => "initial" , :count => 0, :msg => "", :neighbors => neighbors}
                                Worker.start([i,j], wState)
                            end
                        end
                        GenServer.cast(via_tuple([Enum.random(0..num-1),Enum.random(0..num-1)]), {:rumor, "Message"})
                        "rand2D" ->
                            nodes = Enum.map(0..numNodes-1, fn(n)-> [n, :rand.uniform, :rand.uniform] end)
                            Enum.each(nodes, fn([n1,x1,y1]) -> 
                                neighbors =Enum.map( Enum.filter(nodes, fn([n2,x2,y2])-> (x2-x1)*(x2-x1)+(y2-y1)*(y2-y1) < 0.01 and n2 != n1 end),fn([n,_,_])-> n end)
                                wState = %{:server => via_tuple("server"),:id => n1,:state => "initial" , :count => 0, :msg => "", :neighbors => neighbors}
                                Worker.start(n1, wState)
                            end)
                            GenServer.cast(via_tuple(Enum.random(0..numNodes-1)), {:rumor, "Message"})
                        "imp2D"->
                            randomNeighbours = Enum.map(0..numNodes-1, fn(x)-> [x, Enum.random(Enum.reject(0..numNodes-1,fn(x2)-> x2==x end))] end)
                            randomNeighbours = randomNeighbours ++ Enum.map(randomNeighbours, fn([x,y])-> [y,x] end)
                            for i <- 0..numNodes-1 do
                                neighbors = [i-1, i+1] ++ Enum.map(Enum.reject(randomNeighbours, fn([x,_]) -> x != i end),fn([_,y]) -> y end)
                                wState = %{:server => via_tuple("server"),:id => i,:state => "initial" , :count => 0, :msg => "", :neighbors => neighbors}
                                Worker.start(i, wState)
                            end
                            GenServer.cast(via_tuple(Enum.random(0..numNodes-1)), {:rumor, "Message"})
                         _ ->
                                IO.puts "Invaid topology!"
                end
                "pushsum" ->
                    case topology do
                        "full"->
                            for n <- 0..numNodes-1 do
                                wState = %{:server => via_tuple("server"),:id => n,:state => "initial" , :count => 0, :sum => n, :weight => 1, :neighbors => Enum.reject(0..numNodes-1, fn(x)-> x==n end)}
                                Worker.start(n, wState)
                            end
                            GenServer.cast(via_tuple(Enum.random(0..numNodes-1)), {:get_sum, 0, 0}) 
                        "line"->
                            for n <- 0..numNodes-1 do
                                wState = %{:server => via_tuple("server"),:id => n,:state => "initial" , :count => 0, :sum => n, :weight => 1, :neighbors => Enum.reject([n-1,n+1], fn(x)-> (x==-1 || x == numNodes) end)}
                                Worker.start(n, wState)
                            end
                            GenServer.cast(via_tuple(Enum.random(0..numNodes-1)), {:get_sum,0,0})
                        "3D"->
                            num = round(:math.pow(numNodes, 1/3))
                            GenServer.cast(self(), {:set_nodes, num*num*num})
                            for i <- 0..num-1 do
                                for j <- 0..num-1 do
                                    for k <- 0..num-1 do
                                        neighbors = Enum.reject([[i-1,j,k],[i+1,j,k],[i,j-1,k],[i,j+1,k],[i,j,k-1],[i,j,k+1]], fn([x,y,z]) -> (x==-1||y==-1||z==-1||x==num||y==num||z==num) end)
                                        wState = %{:server => via_tuple("server"),:id => [i,j,k],:state => "initial" , :count => 0, :sum => (i*num*num + j*num + k), :weight => 1, :neighbors => neighbors}
                                        Worker.start([i,j,k], wState)
                                    end
                                end
                            end
                            GenServer.cast(via_tuple([Enum.random(0..num-1),Enum.random(0..num-1),Enum.random(0..num-1)]), {:get_sum,0,0})
                        "sphere" ->
                            num = round(:math.pow(numNodes,1/2))
                            GenServer.cast(self(), {:set_nodes, num*num})
                            for i <- 0..num-1 do
                                for j <- 0..num-1 do
                                    neighbors = [[rem(num+i-1,num),j],[rem(num+i+1,num),j],[i,rem(num+j-1,num)],[i,rem(num+j+1,num)]]
                                    wState = %{:server => via_tuple("server"),:id => [i,j],:state => "initial" , :count => 0, :sum => i*num+j, :weight => 1, :neighbors => neighbors}
                                    Worker.start([i,j], wState)
                                end
                            end
                            GenServer.cast(via_tuple([Enum.random(0..num-1),Enum.random(0..num-1)]), {:get_sum,0,0})
                        "rand2D" ->
                                nodes = Enum.map(0..numNodes-1, fn(n)-> [n, :rand.uniform, :rand.uniform] end)
                                Enum.each(nodes, fn([n1,x1,y1]) -> 
                                    neighbors =Enum.map( Enum.filter(nodes, fn([n2,x2,y2])-> (x2-x1)*(x2-x1)+(y2-y1)*(y2-y1) < 0.01 and n2 != n1 end),fn([n,_,_])-> n end)
                                    wState = %{:server => via_tuple("server"),:id => n1,:state => "initial" , :count => 0, :sum => n1, :weight => 1, :neighbors => neighbors}
                                    Worker.start(n1, wState)
                                end)
                                GenServer.cast(via_tuple(Enum.random(0..numNodes-1)), {:get_sum,0,0})
                        "imp2D"->
                                randomNeighbours = Enum.map(0..numNodes-1, fn(x)-> [x, Enum.random(Enum.reject(0..numNodes-1,fn(x2)-> x2==x end))] end)
                                randomNeighbours = randomNeighbours ++ Enum.map(randomNeighbours, fn([x,y])-> [y,x] end)
                                for i <- 0..numNodes-1 do
                                    neighbors = Enum.reject([i-1, i+1] ++ Enum.map(Enum.reject(randomNeighbours, fn([x,_]) -> x != i end),fn([_,y]) -> y end), fn(x) -> x == -1 or x == numNodes end)
                                    wState = %{:server => via_tuple("server"),:id => i,:state => "initial" , :count => 0, :sum => i, :weight => 1, :neighbors => neighbors}
                                    Worker.start(i, wState)
                                end
                                GenServer.cast(via_tuple(Enum.random(0..numNodes-1)), {:get_sum,0,0})
                         _ ->
                                IO.puts "Invaid topology!"
                    end
            _ ->
                IO.puts "Invaid algorithm"
        end
        state = Map.put(state,:starttime, :os.system_time(:millisecond))
        {:ok, state}
    end

    def handle_cast({:converged, _}, state) do
        endTime = :os.system_time(:millisecond) 
        state = Map.put(state, :conv, state[:conv]+1)
        state = Map.put(state, :died, state[:died]+1)
        if(state[:died]/state[:numNodes] >= state[:convrate])do
            s = "#{state[:conv]*100/state[:numNodes]} % converged in #{endTime - state[:starttime]} ms"
            send(state[:main], s)
            die(state, endTime);
        end
        
        {:noreply, state}
    end

    def handle_cast({:got_rumor, _}, state) do
        state = Map.put(state, :reach, state[:reach]+1)
        {:noreply, state}        
    end

    def handle_cast({:dying, _}, state) do
        state = Map.put(state, :died, state[:died]+1)
        {:noreply, state}        
    end

    def handle_cast({:set_nodes, num}, state) do
        state = Map.put(state, :numNodes, num)
        {:noreply, state}        
    end

    def handle_cast({:print, text}, state) do
        print(text)
        {:noreply, state}        
    end

    def print(text) do
        IO.puts text
    end
    def die() do
        Process.exit(self(), :normal)
    end
    def die(state, endTime) do
        IO.puts " #{state[:conv]*100/state[:numNodes]} % converged in #{endTime - state[:starttime]} ms"
        Process.exit(self(), :normal)
    end
    def getconv() do
        state = GenServer.call(via_tuple("server"), :get_conv)
        endTime = :os.system_time(:millisecond) 
        IO.puts("##{state[:conv]*100/state[:numNodes]} % converged in #{endTime - state[:starttime]} ms")
    end
    
    def handle_call(:get_conv, _, state) do
        {:reply, state, state}
    end   

    defp via_tuple(id) do
        {:via, Registry, {:process_registry, id}}
    end
end