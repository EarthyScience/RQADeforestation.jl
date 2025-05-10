using RQADeforestation: rqatrend_impl
using StaticCompiler, StaticTools
using Base: RefValue

@inline function rqatrend_static(data::MallocVector, thresh::Float64, border::Int, theiler::Int)
    @inline rqatrend_impl(data; thresh=thresh, border=border, theiler=theiler)
end

# this will let us accept pointers to MallocArrays
rqatrend_static(data::Ref, thresh::Float64, border::Int, theiler::Int) = rqatrend_static(data[], thresh, border, theiler)

tt = (RefValue{MallocVector{Float64}}, Float64, Int, Int)
compile_shlib(rqatrend_static, tt, "./", "rqatrend", filename="librqatrend")