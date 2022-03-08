""" Seconds since the first sample """
const TimeStamp = Second

# TODO: Support custom fields (wrap NamedTuple)
struct Process
    timestamp::TimeStamp
    pid::Int
    user::Symbol
    priority::Int                                               # PR
    nice::Int                                                   # NI
    virtual_memory_bytes::Int                                   # VIRT
    resident_memory_bytes::Int                                  # RES
    shared_memory_bytes::Int                                    # SHR
    state::Symbol                                               # S
    cpu_usage::Float64                                          # %CPU
    memory_usage::Float64                                       # %MEM
    cpu_time::Float64                                           # TIME+
    command::String
end

struct TimeOfDay
    hour::Int8
    minute::Int8
    second::Int8
end

Base.:(==)(a::TimeOfDay, b::TimeOfDay) =
    a.hour == b.hour && a.minute == b.minute && a.second == b.second

function Base.:<(a::TimeOfDay, b::TimeOfDay)
    a.hour < b.hour && return true
    a.hour > b.hour && return false
    a.minute < b.minute && return true
    a.minute > b.minute && return false
    return a.second < b.second
end

as_seconds(t::TimeOfDay) = 60 * (60 * t.hour + t.minute) + t.second

struct SamplesIterator{IO}
    io::IO
end

mutable struct ProcessIterator{IO}
    timestamp::TimeStamp
    io::IO
    done::Bool
end

struct Sample
    timestamp::TimeStamp
    timeofday::TimeOfDay
    processes::ProcessIterator
end

Base.eltype(::Type{<:SamplesIterator}) = Sample
Base.eltype(::Type{<:ProcessIterator}) = Process

Base.IteratorSize(::Type{<:SamplesIterator}) = Base.SizeUnknown()
Base.IteratorSize(::Type{<:ProcessIterator}) = Base.SizeUnknown()

function Base.iterate(it::SamplesIterator, state = nothing)
    io = it.io

    if state !== nothing
        if !state.pit.done
            while !all(isspace, readline(io))
            end
            state.pit.done = true
        end
    end

    ln = readline(io)
    if all(isspace, ln) && eof(io)
        return nothing
    end

    m = match(r"^top *- *([0-9]{2}):([0-9]{2}):([0-9]{2}) ", ln)
    if m === nothing
        error("unexpected first line of summary: ", ln)
    end
    timeofday = TimeOfDay(parse(Int8, m[1]), parse(Int8, m[2]), parse(Int8, m[3]))

    if state === nothing
        seconds = 0
    else
        seconds = state.seconds
        if timeofday < state.timeofday
            # Assuming the delay (as in `top -d $delay`) is < 1 day
            # TODO: verify this using the uptime information
            rest = 24 * 60 * 60 - as_seconds(state.timeofday)
            @assert rest >= 0
            seconds += rest
            seconds += as_seconds(timeofday)
        else
            seconds += as_seconds(timeofday) - as_seconds(state.timeofday)
        end
    end

    while !all(isspace, readline(io))
    end

    ln = readline(io)
    m = match(
        r"^ +PID +USER +PR +NI +VIRT +RES +SHR +S +%CPU +%MEM +TIME\+ +COMMAND *$",
        ln,
    )
    if m === nothing
        eof(io) && return nothing
        error("unexpected first line of table: ", ln)
    end

    timestamp = Second(seconds)
    pit = ProcessIterator(timestamp, io, false)

    return (Sample(timestamp, timeofday, pit), (; seconds, timeofday, pit))
end

function Base.iterate(it::ProcessIterator, _ignored = nothing)
    timestamp = it.timestamp
    io = it.io
    it.done && return nothing

    ln = readline(io)
    cols = split(ln, limit = 12)
    if length(cols) < 11
        it.done = true
        return nothing
    end

    let (pid, user, pr, ni, virt, res, shr, s, pcpu, pmem, time) = cols
        command = get(cols, 12, "")
        args = (
            tryparse(Int, pid),
            Symbol(user),
            pr == "rt" ? typemax(Int) : tryparse(Int, pr),
            tryparse(Int, ni),
            tryparse_memory(virt),
            tryparse_memory(res),
            tryparse_memory(shr),
            Symbol(s),
            tryparse(Float64, pcpu),
            tryparse(Float64, pmem),
            tryparse_time(time),
            command,
        )
        if all(!isnothing, args)
            return (Process(timestamp, map(something, args)...), nothing)
        end
        cols = join(findall(isnothing, args), ", ", " and ")
        error("unexpected value(s) in column(s) $cols of line: ", ln)
    end
end

function tryparse_memory(str)
    unit = lowercase(str[end])
    endat = lastindex(str) - 1
    if unit == 'k'
        scaling = 2^10
    elseif unit == 'm'
        scaling = 2^20
    elseif unit == 'g'
        scaling = 2^30
    elseif unit == 't'
        scaling = 2^40
    elseif unit == 'p'
        scaling = 2^50
    else
        scaling = 2^10  # KiB
        endat = lastindex(str)
    end
    v = tryparse(Float64, view(str, 1:endat))
    v === nothing && return v
    return trunc(Int, v * scaling)
end

function tryparse_time(str)
    m = match(
        r"""
        ^(?:
            (?<minute>
                [0-9]*
            ):
        )?
        (?<second>
            [0-9]+
            (?:
                \.[0-9]*
            )?
        )$
        """x,
        str,
    )
    m === nothing && return nothing
    return parse(Int, m[:minute]) * 60 + parse(Float64, m[:second])
end
