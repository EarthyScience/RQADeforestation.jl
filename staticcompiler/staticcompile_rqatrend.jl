using RQADeforestation: rqatrend_impl
using StaticCompiler, StaticTools
using Base: RefValue
using BenchmarkTools

@inline function rqatrend_static(data::MallocVector, thresh::Float64, border::Int, theiler::Int)
    @inline rqatrend_impl(data; thresh=thresh, border=border, theiler=theiler)
end

# this will let us accept pointers to MallocArrays
rqatrend_static(data::Ref, thresh::Float64, border::Int, theiler::Int) = rqatrend_static(data[], thresh, border, theiler)

tt = (RefValue{MallocVector{Float64}}, Float64, Int, Int)
# sudo apt install gcc libc-dev
filename = compile_shlib(rqatrend_static, tt, "./")




import Random
Random.seed!(1234)

x = 1:0.01:30
y = sin.(x) + 0.1x + rand(length(x))

trend_impl = rqatrend_impl(y, thresh=0.5, border=10, theiler=1)
@show trend_impl
@benchmark rqatrend_impl($y, thresh=0.5, border=10, theiler=1)

using Libdl
Libdl.dlopen(filename) do lib
    rqatrend_compiled = Libdl.dlsym(lib, :rqatrend_static)
    MallocArray(Float64, length(x)) do my
        my .= y
        trend_malloc = rqatrend_static(my, #=thresh=# 0.5::Float64, #=border=# 10::Int, #=theiler=# 1::Int)
        @show trend_malloc

        ry = Ref(my)
        
        trend_ccall = ccall(rqatrend_compiled, Float64, (Ptr{Nothing}, Float64, Int, Int), pointer_from_objref(ry), #=thresh=# 0.5, #=border=# 10, #=theiler=# 1)
        @show trend_ccall
        @benchmark ccall($rqatrend_compiled, Float64, (Ptr{Nothing}, Float64, Int, Int), $(pointer_from_objref(ry)), #=thresh=# 0.5, #=border=# 10, #=theiler=# 1)

        # second approach how to deal with pointers (seems more safe)
        # and both similarly slow when benchmarked from Julia...
        GC.@preserve ry begin
            py = pointer_from_objref(ry)
            trend_compiled = @ptrcall rqatrend_compiled(py::Ptr{Nothing}, #=thresh=# 0.5::Float64, #=border=# 10::Int, #=theiler=# 1::Int)::Float64
            @show trend_compiled
            @benchmark @ptrcall $rqatrend_compiled($py::Ptr{Nothing}, #=thresh=# 0.5::Float64, #=border=# 10::Int, #=theiler=# 1::Int)::Float64
        end
    end
end