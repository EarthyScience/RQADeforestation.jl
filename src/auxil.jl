using YAXArrayBase:  backendlist, get_var_handle
using DiskArrayTools
using DiskArrays: DiskArrays, GridChunks
using DimensionalData: DimensionalData as DD, X, Y
using GeoFormatTypes
#using PyramidScheme: PyramidScheme as PS
using Rasters: Raster

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
    m = match(reg, x).match
    date = DateTime(m, df)
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
    @assert sort(times) == times
    group = [1]
    groups = [group]

    for i in 2:length(times)
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

function gdalcube(filenames::AbstractVector{<:AbstractString})
    dates = getdate.(filenames)
    # Sort the dates and files by DateTime
    p = sortperm(dates)
    sdates = dates[p]
    sfiles = filenames[p]
    taxis = DD.Ti(sdates)

    #@show sdates
    # Put the dates which are 200 seconds apart into groups
    #groupinds = grouptimes(sdates, 200000)

    #datasets = AG.readraster.(sfiles)
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
    attrs["scale_factor"] = Float16(attrs["scale_factor"])
    all_cfs = CFDiskArray(stacked_gdbs, attrs)
    return YAXArray((onecube.axes..., taxis), all_cfs, onecube.properties)
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


"""
agcube(filenames)
   Open the underlying tiff files via ArchGDAL.
   This opens all files and keeps them open.
   This has a higher upfront cost, but might lead to a speedup down the line when we access the data.
"""
function agcube(filenames::AbstractVector{<:AbstractString})
    dates = RQADeforestation.getdate.(filenames)
    # Sort the dates and files by DateTime
    p = sortperm(dates)
    sdates = dates[p]
    sfiles = filenames[p]
    taxis = Ti(sdates)
    datasets = AG.readraster.(sfiles)
    yaxlist = YAXArray.(datasets)
    return concatenatecubes(yaxlist, taxis)
end

function netcdfify(path)
    c = Cube(path)
    npath = splitext(path)[1] * ".nc"
    fl32 = map(x -> ismissing(x) ? x : Float32(x), c)
    fl32.properties["_FillValue"] *= 1.0f0
    savecube(fl32, npath; compress=5)
end

const equi7crs = Dict(
    "AF" => ProjString("+proj=aeqd +lat_0=8.5 +lon_0=21.5 +x_0=5621452.01998 +y_0=5990638.42298 +datum=WGS84 +units=m +no_defs"),
    "AN" => ProjString("+proj=aeqd +lat_0=-90 +lon_0=0 +x_0=3714266.97719 +y_0=3402016.50625 +datum=WGS84 +units=m +no_defs"),
    "AS" => ProjString("+proj=aeqd +lat_0=47 +lon_0=94 +x_0=4340913.84808 +y_0=4812712.92347 +datum=WGS84 +units=m +no_defs"),
    "EU" => ProjString("+proj=aeqd +lat_0=53 +lon_0=24 +x_0=5837287.81977 +y_0=2121415.69617 +datum=WGS84 +units=m +no_defs"),
    "NA" => ProjString("+proj=aeqd +lat_0=52 +lon_0=-97.5 +x_0=8264722.17686 +y_0=4867518.35323 +datum=WGS84 +units=m +no_defs"),
    "OC" => ProjString("+proj=aeqd +lat_0=-19.5 +lon_0=131.5 +x_0=6988408.5356 +y_0=7654884.53733 +datum=WGS84 +units=m +no_defs"),
    "SA" => ProjString("+proj=aeqd +lat_0=-14 +lon_0=-60.5 +x_0=7257179.23559 +y_0=5592024.44605 +datum=WGS84 +units=m +no_defs")
)

# Auxillary functions for masking with the forest data

function getsubtiles(tile)
    east = eastint(tile)
    north = northint(tile)
    tiles = ["E$(lpad(e,3,"0"))N$(lpad(n, 3, "0"))T1" for e in east:(east+2), n in north:(north+2)]
    return tiles
end

eastint(tile) = parse(Int, tile[2:4])
northint(tile) = parse(Int, tile[6:8])



function aggregate_forestry(tile)
    subtiles = getsubtiles(tile)
    foresttiles = [(parse.(Int, match(r"E(\d\d\d)N(\d\d\d)T1", t).captures)...,) => "/eodc/private/pangeojulia/ForestType/2017_FOREST-CLASSES_EU010M_$(t).tif" for t in subtiles]
    filledtiles = filter(x -> isfile(last(x)), foresttiles)
    if isempty(filledtiles)
        return nothing
    end


    idx_to_fname = Dict(filledtiles...)
    a = Cube(last(first(filledtiles)))
    east = eastint(tile)
    north = northint(tile)
    f = ChunkedFillArray(a[1, 1], size(a), size.(DiskArrays.eachchunk(a)[1], 1))
    allarrs = [haskey(idx_to_fname, (x, y)) ? Cube(idx_to_fname[(x, y)]).data : f for x in east:(east+2), y in north:(north+2)]

    yaxs = Cube.(last.(filledtiles))
    #ext = Extents.union(yaxs...)
    #tilex = Rasters._mosaic(first.(dims.(yaxs))...)
    #tiley = Rasters._mosaic(last.(dims.(yaxs))...)
    diskarray_merged = DiskArrayTools.ConcatDiskArray(allarrs)

    # We should first do the pyramid computation and then stitch non values along


    #foryax = Cube.(filledtiles)
    #forest = YAXArrays.Datasets.open_mfdataset(vec(foresttiles))

    aggfor = [PS.gen_output(Union{Int8,Missing}, ceil.(Int, size(c) ./ 2)) for c in yaxs]
    #a = aggfor[1]
    #yax = foryax[1]
    #PS.fill_pyramids(yax, a, x->sum(x) >0,true)
    println("Start aggregating")
    @time [PS.fill_pyramids(yaxs[i].data, aggfor[i], x -> count(!iszero, x) == 4 ? true : missing, true) for i in eachindex(yaxs)]
    #tilepath = joinpath(indir, tile * suffix)
    #aggyax = [Raster(aggfor[i][1][:,:,1], (PS.agg_axis(dims(yax,X), 2), PS.agg_axis(dims(yax, Y), 2))) for (i, yax) in enumerate(foryax)]
    #ras = Raster(tilepath)
    #allagg = ConcatDiskArray(only.(aggfor)[:,[3,2,1]])

    #allagg = ConcatDiskArray(aggfor[:,[3,2,1]])
    #allagg = ConcatDiskArray(only.(aggfor))
    forras = Raster.(foresttiles, lazy=true)
    xaxs = DD.dims.(forras[:, 1], X)
    xaxsnew = [xax[begin:2:end] for xax in xaxs]
    xax = vcat(xaxsnew...)
    yaxs = DD.dims.(forras[1, :], Y)
    yaxsnew = [yax[begin:2:end] for yax in yaxs]
    yax = vcat(reverse(yaxsnew)...)
    YAXArray((xax, yax), allagg[:, :, 1])
end

function maskforests(tilepath, outdir=".")
    tile = match(r"E\d\d\dN\d\d\dT3", tilepath).match
    forras = aggregate_forestry(tile)
    ras = Raster(tilepath)
    mras = forras .* ras
    write(joinpath(outdir, "forestmasked_all" * tile * suffix), mras)
end