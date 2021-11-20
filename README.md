# TopParser

TopParser.jl provides functions for parsing output of the `top` command.

## Example

```julia
julia> io = IOBuffer(read(`top -b -i -H -w 256 -d 1 -n 10`));  # takes 10 seconds

julia> using TopParser

julia> processes = collect(TopParser.processes(io));

julia> using DataFrames

julia> df = DataFrame(processes);  # `processes` is a table

julia> seekstart(io);

julia> samples = map(s -> collect(s.processes), TopParser.samples(io));
```
