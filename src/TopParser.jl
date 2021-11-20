baremodule TopParser

function processes end
function processes_from_file end

function samples end
function open_samples end

module Internal

using Dates: Second

using ..TopParser: TopParser

include("parser.jl")
include("api.jl")

end  # module Internal

end  # baremodule TopParser
