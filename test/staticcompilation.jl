@testitem "staticcompilation julia" begin

    using RQADeforestation: rqatrend_impl
    using StaticTools
    using BenchmarkTools
    using Libdl
    import Random
    Random.seed!(1234)

    
    filename = joinpath(dirname(dirname(@__FILE__)), "staticcompiler", "lib", "rqatrend.$(Libdl.dlext)")

    if isfile(filename)
        x = 1:0.01:30
        y = sin.(x) + 0.1x + rand(length(x))

        trend_truth = -0.11125611687816017
        trend_impl = rqatrend_impl(y, thresh=0.5, border=10, theiler=1)
        @test trend_impl == trend_truth
        # @benchmark rqatrend_impl($y, thresh=0.5, border=10, theiler=1)

        Libdl.dlopen(filename) do lib

            # test running single c-compiled version

            rqatrend_compiled = Libdl.dlsym(lib, :rqatrend)
            MallocArray(Float64, length(x)) do my
                my .= y
                
                # trend_malloc = rqatrend_static(my, #=thresh=# 0.5::Float64, #=border=# 10::Int, #=theiler=# 1::Int)
                # @show trend_malloc

                ry = Ref(my)
                
                trend_ccall = ccall(rqatrend_compiled, Float64, (Ptr{Nothing}, Float64, Int, Int), pointer_from_objref(ry), #=thresh=# 0.5, #=border=# 10, #=theiler=# 1)
                @test trend_ccall == trend_truth
                # @benchmark ccall($rqatrend_compiled, Float64, (Ptr{Nothing}, Float64, Int, Int), $(pointer_from_objref(ry)), #=thresh=# 0.5, #=border=# 10, #=theiler=# 1)

                # second approach how to deal with pointers (seems more safe)
                # and both similarly slow when benchmarked from Julia...
                GC.@preserve ry begin
                    py = pointer_from_objref(ry)
                    trend_ptrcall = @ptrcall rqatrend_compiled(py::Ptr{Nothing}, #=thresh=# 0.5::Float64, #=border=# 10::Int, #=theiler=# 1::Int)::Float64
                    @test trend_ptrcall == trend_truth
                    # @benchmark @ptrcall $rqatrend_compiled($py::Ptr{Nothing}, #=thresh=# 0.5::Float64, #=border=# 10::Int, #=theiler=# 1::Int)::Float64
                end
            end

            # test running the same multiple on C level

            rqatrend_inplace_compiled = Libdl.dlsym(lib, :rqatrend_inplace)
            n = 5
            MallocArray(Float64, n) do mresults
                MallocArray(Float64, length(x), n) do mdata
                    for i in 1:n
                        mdata[:, i] .= y
                    end
                
                    rresults = Ref(mresults)
                    rdata = Ref(mdata)
                    
                    return_ccall = ccall(rqatrend_inplace_compiled, Int, (Ptr{Nothing}, Ptr{Nothing}, Float64, Int, Int), pointer_from_objref(rresults), pointer_from_objref(rdata), #=thresh=# 0.5, #=border=# 10, #=theiler=# 1)
                    @test return_ccall == 0
                    @test all(mresults .== trend_truth)
                    # @benchmark ccall($rqatrend_inplace_compiled, Int, (Ptr{Nothing}, Ptr{Nothing}, Float64, Int, Int), $(pointer_from_objref(rresults)), $(pointer_from_objref(rdata)), #=thresh=# 0.5, #=border=# 10, #=theiler=# 1)

                    # second approach how to deal with pointers (seems more safe)
                    # and both similarly slow when benchmarked from Julia...
                    GC.@preserve rresults rdata begin
                        presults = pointer_from_objref(rresults)
                        pdata = pointer_from_objref(rdata)

                        return_ptrcall = @ptrcall rqatrend_inplace_compiled(presults::Ptr{Nothing}, pdata::Ptr{Nothing}, #=thresh=# 0.5::Float64, #=border=# 10::Int, #=theiler=# 1::Int)::Int
                        @test return_ptrcall == 0
                        @test all(mresults .== trend_truth)
                        # @benchmark @ptrcall $rqatrend_inplace_compiled($presults::Ptr{Nothing}, $pdata::Ptr{Nothing}, #=thresh=# 0.5::Float64, #=border=# 10::Int, #=theiler=# 1::Int)::Int
                    end
                end
            end
        end
    end
end

@testitem "staticcompilation python" begin
    using PythonCall
    using Libdl
    filename = joinpath(dirname(dirname(@__FILE__)), "staticcompiler", "lib", "rqatrend.$(Libdl.dlext)")

    if isfile(filename)
        pythoncode = """
        import ctypes as ct
        import numpy as np    
        np.random.seed(1234)

        class MallocVector(ct.Structure):
            _fields_ = [("pointer", ct.c_void_p),
                        ("length", ct.c_int64),
                        ("s1", ct.c_int64)]

        class MallocMatrix(ct.Structure):
            _fields_ = [("pointer", ct.c_void_p),
                        ("length", ct.c_int64),
                        ("s1", ct.c_int64),
                        ("s2", ct.c_int64)]

        def mvptr(A):
            ptr = A.ctypes.data_as(ct.c_void_p)
            a = MallocVector(ptr, ct.c_int64(A.size), ct.c_int64(A.shape[0]))
            return ct.byref(a)

        def mmptr(A):
            ptr = A.ctypes.data_as(ct.c_void_p)
            a = MallocMatrix(ptr, ct.c_int64(A.size), ct.c_int64(A.shape[1]), ct.c_int64(A.shape[0]))
            return ct.byref(a)

        filename = "$filename"
        lib = ct.CDLL(filename)

        x = np.arange(1, 30, step=0.01)
        y = np.sin(x) + 0.1 * x + np.random.rand(len(x))
        py = mvptr(y)
        
        # arguments: data, threshhold, border, theiler
        lib.rqatrend.argtypes = (ct.POINTER(MallocVector), ct.c_double, ct.c_int64, ct.c_int64)
        lib.rqatrend.restype = ct.c_double
        result_single = lib.rqatrend(py, 0.5, 10, 1)

        n = 5
        result_several = np.ones(n)
        p_result_several = mvptr(result_several)
        data = np.tile(y, (n, 1))
        pdata = mmptr(data)
        
        # arguments: result_vector, data, threshhold, border, theiler
        lib.rqatrend_inplace.argtypes = (ct.POINTER(MallocVector), ct.POINTER(MallocMatrix), ct.c_double, ct.c_int64, ct.c_int64)
        return_value = lib.rqatrend_inplace(p_result_several, pdata, 0.5, 10, 1)
        """

        results = pyexec(
            @NamedTuple{n::Int, result_single::Float64, return_value::Int, result_several::Vector{Float64}},
            pythoncode,
            Main,
        )
        target_result = -0.11931512705232977
        @test isapprox(results.result_single, target_result)
        @test results.return_value == 0
        @test all(isapprox.(results.result_several, fill(target_result, (results.n,))))
    end
end