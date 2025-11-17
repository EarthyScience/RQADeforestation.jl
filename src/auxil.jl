using YAXArrayBase: backendlist, get_var_handle
using DiskArrayTools
using DiskArrays: DiskArrays, GridChunks
using DiskArrayEngine: DiskArrayEngine as DAE
using DimensionalData: DimensionalData as DD, X, Y
using GeoFormatTypes
using Rasters: Raster
import DiskArrays: readblock!, IrregularChunks, AbstractDiskArray
using StatsBase: rle
using Statistics: mean

#DiskArrays.readblock!(a::AbstractArray,aout,i::AbstractUnitRange...) = copyto!(aout,view(a,i...))

struct LazyAggDiskArray{T,F,A} <: AbstractDiskArray{T,3}
    f::F
    arrays::A
    inds::IrregularChunks
    s::Tuple{Int,Int,Int}
end
function LazyAggDiskArray(f, arrays, groups)
    allequal(size, arrays) || error("All Arrays must have same size")
    allequal(eltype, arrays) || error("All Arrays must have same element type")
    inds = IrregularChunks(; chunksizes=last(rle(groups)))
    s = (size(first(arrays))..., length(inds))
    T = Base.promote_op(f, Vector{eltype(first(arrays))})
    LazyAggDiskArray{T,typeof(f),typeof(arrays)}(f, arrays, inds, s)
end
Base.size(a::LazyAggDiskArray) = a.s
DiskArrays.haschunks(a::LazyAggDiskArray) = DiskArrays.haschunks(first(a.arrays))
function DiskArrays.readblock!(a::LazyAggDiskArray, aout, i::UnitRange{Int}...)
    i1, i2, itime = i
    max_n_array = maximum(it -> length(a.inds[it]), itime)
    buf = zeros(eltype(first(a.arrays)), length(i1), length(i2), max_n_array)
    for (j, it) in enumerate(itime)
        arrays_now = a.arrays[a.inds[it]]
        for ia in eachindex(arrays_now)
            try
                DiskArrays.readblock!(arrays_now[ia], view(buf, :, :, ia), i1, i2)
            catch e
                if hasproperty(e, :captured) && e.captured.ex isa ArchGDAL.GDAL.GDALError
                    @warn e.captured.ex.msg
                    buf[:,:,ia] .= missing
                else
                    rethrow(e)
                end
            end
        end
        vbuf = view(buf, :, :, 1:length(arrays_now))
        map!(a.f, view(aout, :, :, j), eachslice(vbuf, dims=(1, 2)))
    end
end


struct BufferGDALBand{T} <: AG.DiskArrays.AbstractDiskArray{T,2}
    filename::String
    band::Int
    size::Tuple{Int,Int}
    attrs::Dict{String,Any}
    cs::GridChunks{2}
    pointerbuffer::Dict{Int,AG.IRasterBand{T}}
end
function BufferGDALBand(b, filename, i)
    s = size(b)
    atts = getbandattributes(b)
    BufferGDALBand{AG.pixeltype(b)}(filename, i, s, atts, eachchunk(b), Dict{Int,Ptr{AG.GDAL.GDALRasterBandH}}())
end
Base.size(b::BufferGDALBand) = b.size
DiskArrays.eachchunk(b::BufferGDALBand) = b.cs
DiskArrays.haschunks(::BufferGDALBand) = DiskArrays.Chunked()
function DiskArrays.readblock!(b::BufferGDALBand, aout, r::AbstractUnitRange...)
    @debug "Before get: ", isempty(b.pointerbuffer)
    bandpointer = get!(b.pointerbuffer, myid()) do
        @debug "Opening file $(b.filename) band $(b.band)"
        AG.getband(AG.readraster(b.filename), b.band)
    end
    @debug "After get: ", isempty(b.pointerbuffer)
    DiskArrays.readblock!(bandpointer, aout, r...)
end

function getdate(x, reg=r"[0-9]{8}T[0-9]{6}", df=dateformat"yyyymmddTHHMMSS")
    m = match(reg, x)
    isnothing(m) && throw(ArgumentError("Did not find a datetime information in $x"))
    date = DateTime(m.match, df)
end

@testitem "getdate" begin
    using Dates
    @test RQADeforestation.getdate("sometext20200919T202020_somemoretext1234") == DateTime(2020, 9, 19, 20, 20, 20)
    @test_throws Exception RQADeforestation.getdate("sometext")
end

"""
gdalcube(indir, pol)

Load the datasets in `indir` with a polarisation `pol` as a ESDLArray.
We assume, that `indir` is a folder with geotiffs in the same CRS which are mosaicked into timesteps and then stacked as a threedimensional array.

"""
function gdalcube(indir, pol)
    filenames = glob("*$(pol)*.tif", indir)
    gdalcube(filenames)
end

"""
grouptimes(times, timediff=200000)
Group a sorted vector of time stamps into subgroups
where the difference between neighbouring elements are less than `timediff` milliseconds.
This returns the indices of the subgroups as a vector of vectors.
"""
function grouptimes(times, timediff=200000)
    @assert issorted(times)
    group = [1]
    groups = [group]

    for i in eachindex(times)[2:end]
        t = times[i]
        period = t - times[group[end]]
        if period.value < timediff
            push!(group, i)
        else
            push!(groups, [i])
            group = groups[end]
        end
    end
    return groups
end


function stackindices(times, timediff=200000)
    @assert issorted(times)
    groups = zero(eachindex(times))
    group = 1
    groups[1] = group

    for i in eachindex(times)[2:end]
        period = times[i] - times[i-1]
        if period.value < timediff
            groups[i] = group
        else
            group += 1
            groups[i] = group
        end
    end
    return groups
end

#=
function DiskArrays.readblock!(b::GDALBand, aout, r::AbstractUnitRange...)
   if !isa(aout,Matrix)
      aout2 = similar(aout)
      AG.read(b.filename) do ds
         AG.getband(ds, b.band) do bh
             DiskArrays.readblock!(bh, aout2, r...)
         end
     end
     aout .= aout2
   else   
   AG.read(b.filename) do ds
       AG.getband(ds, b.band) do bh
           DiskArrays.readblock!(bh, aout, r...)
       end
   end
   end
end
=#

function gdalcube(filenames::AbstractVector{<:AbstractString}, stackgroups=:dae)
    dates = getdate.(filenames)
    @show length(dates)
    # Sort the dates and files by DateTime
    p = sortperm(dates)
    sdates = dates[p]
    sfiles = filenames[p]

    #@show sdates
    # Put the dates which are 200 seconds apart into groups
    if stackgroups in [:dae, :lazyagg]
        groupinds = grouptimes(sdates, 200000)
        onefile = first(sfiles)
        gd = backendlist[:gdal]
        yax1 = gd(onefile)
        #gdb = yax1["Gray"]
        #onecube = Cube(onefile)
        #@show onecube.axes
        gdb = get_var_handle(yax1, "Gray")
        gdbband = gdb.band
        gdbsize = gdb.size
        gdbattrs = gdb.attrs
        gdbcs = gdb.cs
        group_gdbs = map(sfiles) do f
            BufferGDALBand{eltype(gdb)}(f, gdbband, gdbsize, gdbattrs, gdbcs, Dict{Int,AG.IRasterBand}())
        end

        cubelist = CFDiskArray.(group_gdbs, (gdbattrs,))
        stackinds = stackindices(sdates)
        aggdata = if stackgroups == :dae
            gcube = diskstack(cubelist)
            aggdata = DAE.aggregate_diskarray(gcube, mean ∘ skipmissing, (3 => stackinds,); strategy=:direct)
        else
            println("Construct lazy diskarray")
            LazyAggDiskArray(skipmissingmean, cubelist, stackinds)
        end
        #    data = DiskArrays.ConcatDiskArray(reshape(groupcubes, (1,1,length(groupcubes))))
        dates_grouped = [sdates[group[begin]] for group in groupinds]

        taxis = DD.Ti(dates_grouped)
        gcube = Cube(sfiles[1])
        return YAXArray((DD.dims(gcube)[1:2]..., taxis), aggdata, gcube.properties,)
    else
        #datasets = AG.readraster.(sfiles)
        taxis = DD.Ti(sdates)

        onefile = first(sfiles)
        gd = backendlist[:gdal]
        yax1 = gd(onefile)
        onecube = Cube(onefile)
        #@show onecube.axes
        gdb = get_var_handle(yax1, "Gray")

        #@assert gdb isa GDALBand
        all_gdbs = map(sfiles) do f
            BufferGDALBand{eltype(gdb)}(f, gdb.band, gdb.size, gdb.attrs, gdb.cs, Dict{Int,AG.IRasterBand}())
        end
        stacked_gdbs = diskstack(all_gdbs)
        attrs = copy(gdb.attrs)
        #attrs["add_offset"] = Float16(attrs["add_offset"])
        if haskey(attrs, "scale_factor")
            attrs["scale_factor"] = Float16(attrs["scale_factor"])
        end
        all_cfs = CFDiskArray(stacked_gdbs, attrs)
        return YAXArray((onecube.axes..., taxis), all_cfs, onecube.properties)
    end
    #datasetgroups = [datasets[group] for group in groupinds]
    #We have to save the vrts because the usage of nested vrts is not working as a rasterdataset
    #temp = tempdir()
    #outpaths = [joinpath(temp, splitext(basename(sfiles[group][1]))[1] * ".vrt") for group in groupinds]
    #vrt_grouped = AG.unsafe_gdalbuildvrt.(datasetgroups)
    #AG.write.(vrt_grouped, outpaths)
    #vrt_grouped = AG.read.(outpaths)
    #vrt_vv = AG.unsafe_gdalbuildvrt(vrt_grouped, ["-separate"])
    #rvrt_vv = AG.RasterDataset(vrt_vv)
    #yaxras = YAXArray.(sfiles)
    #cube = concatenatecubes(yaxras, taxis)
    #bandnames = AG.GDAL.gdalgetfilelist(vrt_vv.ptr)



    # Set the timesteps from the bandnames as time axis
    #dates_grouped = [sdates[group[begin]] for group in groupinds]
end

function skipmissingmean(x)
    isempty(x) && return missing
    s,n = reduce(x,init=(zero(eltype(x)),0)) do (s,n), ix
        ismissing(ix) ? (s,n) : (s+ix,n+1)
    end
    n==0 ? missing : s/n
end
#Base.∘(::typeof(mean), ::typeof(skipmissing)) = skipmissingmean

const equi7crs = Dict(
    "AF" => ProjString("+proj=aeqd +lat_0=8.5 +lon_0=21.5 +x_0=5621452.01998 +y_0=5990638.42298 +datum=WGS84 +units=m +no_defs"),
    "AN" => ProjString("+proj=aeqd +lat_0=-90 +lon_0=0 +x_0=3714266.97719 +y_0=3402016.50625 +datum=WGS84 +units=m +no_defs"),
    "AS" => ProjString("+proj=aeqd +lat_0=47 +lon_0=94 +x_0=4340913.84808 +y_0=4812712.92347 +datum=WGS84 +units=m +no_defs"),
    "EU" => ProjString("+proj=aeqd +lat_0=53 +lon_0=24 +x_0=5837287.81977 +y_0=2121415.69617 +datum=WGS84 +units=m +no_defs"),
    "NA" => ProjString("+proj=aeqd +lat_0=52 +lon_0=-97.5 +x_0=8264722.17686 +y_0=4867518.35323 +datum=WGS84 +units=m +no_defs"),
    "OC" => ProjString("+proj=aeqd +lat_0=-19.5 +lon_0=131.5 +x_0=6988408.5356 +y_0=7654884.53733 +datum=WGS84 +units=m +no_defs"),
    "SA" => ProjString("+proj=aeqd +lat_0=-14 +lon_0=-60.5 +x_0=7257179.23559 +y_0=5592024.44605 +datum=WGS84 +units=m +no_defs")
)