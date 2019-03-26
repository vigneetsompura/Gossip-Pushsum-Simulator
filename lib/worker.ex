defmodule Worker do
    use GenServer

    def start(id, state) do
        name = via_tuple(id)
        GenServer.start_link(__MODULE__, state, name: name)
    end

    def init(state) do
        if(state[:neighbors] == []) do
            GenServer.cast(state[:server], {:converged, state[:id]})
            Process.exit(self(), :normal)
        end
        state = Map.put(state, :mcount, 0)
        state = Map.put(state, :fcount, 0)
        {:ok, state}
    end

    def handle_cast({:rumor, msg}, state) do
        if(state[:state] == "initial") do
            state = Map.put(state, :msg, msg)
            state = Map.put(state, :state, "rumoring")
            state = Map.put(state, :count, state[:count]+1)
            GenServer.cast(state[:server], {:got_rumor, state[:id]})
            GenServer.cast(self(), {:startrumor, msg})
            {:noreply, state}
        else 
            state = Map.put(state, :count, state[:count]+1)
            if(state[:count] == 10) do
                Enum.each(state[:neighbors], fn(x) -> 
                    GenServer.cast(via_tuple(x), {:removeneighbor, state[:id]})
                end)
                GenServer.cast(state[:server], {:converged, state[:id]})
                Process.exit(self(), :normal)
            end
            {:noreply, state}
        end
    end    

    def handle_cast({:startrumor, msg}, state) do
        unless (state[:neighbors] == []) do
            GenServer.cast(via_tuple(Enum.random(state[:neighbors])), {:rumor, msg})
            :timer.sleep(100)
            GenServer.cast(self(), {:startrumor, msg})
        end
        {:noreply, state}
    end

    def handle_cast({:get_sum, s, w}, state) do
       
        sum = state[:sum]
        weight = state[:weight]
        state = if(((sum+s)/(weight+w)) - (sum/weight) <= :math.pow(10,-10)) do
            Map.put(state, :count, state[:count]+1)
        else
            Map.put(state, :count, 0)
        end
        state = Map.put(state, :sum, sum+s)
        state = Map.put(state, :weight, weight+w)
        state = Map.put(state, :mcount, state[:mcount]+1)
        if(state[:state] == "initial") do
            state = Map.put(state, :state, "rumoring")
            GenServer.cast(self(), {:push_sum, state, state[:mcount]})
            {:noreply, state}
        else 
            if(state[:count] == 3) do
                Enum.each(state[:neighbors], fn(x) -> 
                    GenServer.cast(via_tuple(x), {:removeneighbor, state[:id]})
                end)
                GenServer.cast(state[:server], {:converged, state[:id]})
                Process.exit(self(), :normal)
            end
            {:noreply, state}
        end
    end    


    def handle_cast({:push_sum, st, mcount}, state) do
        unless (state[:neighbors] == []) do
            sum = st[:sum]
            weight = st[:weight]
            fcount = state[:fcount]
            if (state[:mcount] > mcount) do
                GenServer.cast(self(), {:no_update, 0})
            else
                GenServer.cast(self(), {:no_update, fcount + 1})
            end

            if (fcount >= 10) do
                GenServer.cast(state[:server], {:converged, state[:id]})
                Process.exit(self(), :normal)
            end
            state = Map.put(state, :sum, sum/2)
            state = Map.put(state, :weight, weight/2)
            GenServer.cast(via_tuple(Enum.random(state[:neighbors])), {:get_sum, sum/2, weight/2})
            :timer.sleep(100)
            GenServer.cast(self(), {:push_sum, state, state[:mcount]})
        end
        {:noreply, state}
    end

    def handle_cast({:no_update, status}, state) do
        state = Map.put(state, :fcount, status)
        {:noreply, state}
    end

    def handle_cast({:removeneighbor, id}, state) do
        state = Map.put(state, :neighbors, Enum.reject(state[:neighbors], fn(x)-> x == id end))
        if (length(state[:neighbors])==0) do
            GenServer.cast(state[:server], {:converged, state[:id]})
            Process.exit(self(), :normal)
        end
        {:noreply, state}
    end

    defp via_tuple(id) do
        {:via, Registry, {:process_registry, id}}
    end 
end