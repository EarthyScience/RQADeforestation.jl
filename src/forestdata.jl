
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