"""
    TopParser.samples(content::Union{IO,AbstractString}) -> samplesitr
"""
TopParser.samples
TopParser.samples(content::AbstractString) = SamplesIterator(IOBuffer(content))
TopParser.samples(io::IO) = SamplesIterator(io)

"""
    TopParser.open_samples(f, path)
"""
TopParser.open_samples
function TopParser.open_samples(f, path)
    open(path) do io
        f(TopParser.samples(io))
    end
end

"""
    TopParser.processes(content::Union{IO,AbstractString})
    TopParser.processes(samplesitr)
"""
TopParser.processes
TopParser.processes(content::Union{IO,AbstractString}) =
    TopParser.processes(TopParser.samples(content))
TopParser.processes(samples::SamplesIterator) =
    Iterators.flatten(Iterators.map(get_processes, samples))

get_processes(sample::Sample) = sample.processes

"""
    TopParser.processes_from_file([pred,] path) -> processes::Vector{Process}
"""
TopParser.processes_from_file
TopParser.processes_from_file(path) = TopParser.processes_from_file(always, path)
function TopParser.processes_from_file(pred, path)
    TopParser.open_samples(path) do samples
        collect(Iterators.filter(pred, TopParser.processes(samples)))
    end
end

always(_) = true
