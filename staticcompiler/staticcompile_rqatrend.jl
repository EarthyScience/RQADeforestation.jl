using RQADeforestation: rqatrend_impl
using LoopVectorization
using StaticCompiler
using StaticTools
using Base: RefValue

@inline function rqatrend(data::MallocVector, thresh::Float64, border::Int, theiler::Int)
    @inline rqatrend_impl(data; thresh=thresh, border=border, theiler=theiler)
end

@inline function rqatrend_inplace(results::MallocVector, data::MallocMatrix, thresh::Float64, border::Int, theiler::Int)
    # we cannot use LoopVectorization.@turbo because of keyword arguments
    # see https://github.com/JuliaSIMD/LoopVectorization.jl/pull/494
    for col in eachindex(results)  # col in indices((results, data), (1, 2))
        results[col] = @inline rqatrend_impl(data[:, col]; thresh=thresh, border=border, theiler=theiler) 
    end
    return 0
end

# this will let us accept pointers to MallocArrays
rqatrend(data::Ref, thresh::Float64, border::Int, theiler::Int) = rqatrend(data[], thresh, border, theiler)
rqatrend_inplace(results::Ref, data::Ref, thresh::Float64, border::Int, theiler::Int) = rqatrend_inplace(results[], data[], thresh, border, theiler)

funcs_and_types = (
    (rqatrend, (RefValue{MallocVector{Float64}}, Float64, Int, Int)),
    (rqatrend_inplace, (RefValue{MallocVector{Float64}}, RefValue{MallocMatrix{Float64}}, Float64, Int, Int)),
)

# sudo apt install gcc libc-dev
compile_shlib(funcs_and_types, "./lib/", filename="rqatrend")