using ImageMorphology, Zarr, YAXArrays
import DimensionalData as DD
import DiskArrayEngine as DAE
using DataStructures: counter
using Statistics
using FillArrays
#maskfolder = "data/forestcompressed"

function meanvote(orbits, significance_thresh=50)
    s, n = 0.0, 0
    for i in eachindex(orbits)
        if !ismissing(orbits[i]) && orbits[i] != 0 && !isnan(orbits[i])
            s += orbits[i]
            n += 1
        end
    end
    m = s / n
    return m < significance_thresh ? 1 : 0
end

function filtersmallcomps!(
    xout, xin_unfiltered, forestmask, comborbits, connsize; dims=:, threaded=false
)
    xin = broadcast(xin_unfiltered, forestmask) do x, m
        ismissing(m) ? zero(x) : x * (m == 1)
    end
    x = similar(Array{Float64}, (axes(xin, 1), axes(xin, 2), Base.OneTo(1)))
    for j in axes(x, 2), i in axes(x, 1)
        x[i, j, 1] = comborbits(view(xin, i, j, :))
    end
    lc = label_components(x)
    c = counter(lc)
    for ix in eachindex(xout)
        v = lc[ix]
        if v == 0 || c[v] < connsize
            xout[ix] = 0
        else
            xout[ix] = 1
        end
    end
end

function postprocess(
    a::YAXArray,
    target_array::YAXArray,
    forestmask::YAXArray,
    orbitcombine=meanvote;
    minsize=30,
    max_cache=5e8,
)
    nx, ny, nz = size(a)
    windowsx = DAE.MovingWindow(1 - minsize, 1, 2 * minsize + 1, nx, (1, nx))
    windowsy = DAE.MovingWindow(1 - minsize, 1, 2 * minsize + 1, ny, (1, ny))
    windowsz = [1:nz]
    inar1 = DAE.InputArray(a.data; windows=(windowsx, windowsy, windowsz))
    inar2 = DAE.InputArray(forestmask.data; windows=(windowsx, windowsy))
    inars = (inar1, inar2)
    outchunks = (target_array.chunks.chunks..., DAE.RegularChunks(1, 0, 1))
    outars = DAE.create_outwindows((nx, ny, 1); chunks=outchunks)
    uf = DAE.create_userfunction(
        filtersmallcomps!,
        UInt8;
        is_blockfunction=true,
        is_mutating=true,
        args=(orbitcombine, minsize),
    )
    op = DAE.GMDWop(inars, (outars,), uf)
    plan = DAE.optimize_loopranges(op, max_cache)
    runner = DAE.LocalRunner(op, plan, (reshape(target_array.data, (nx, ny, 1)),))
    run(runner)
    return target_array
end

function postprocess(tile::AbstractString, indir, outpath, maskfolder)
    if isdir(outpath)
        return nothing
    end

    forpath = only(glob("*$tile*", maskfolder))
    @show forpath
    allfiles = readdir(indir; join=true)
    @show allfiles
    orbitfiles = filter(x -> occursin(tile, string(x)), allfiles)
    @show orbitfiles
    orbits = filter(x -> occursin(".zarr", string(x)), orbitfiles)
    @show orbits
    orbitname = map(o -> split(basename(o), '_')[4], orbits)
    d = DD.format(Dim{:orbit}(orbitname))
    files = DD.DimArray(orbits, d)
    ds = open_mfdataset(string.(files))
    nx, ny = size(ds.layer)
    outds_skeleton = Dataset(;
        defo=YAXArray(
            (ds.X, ds.Y),
            Fill(UInt8(0), nx, ny);
            chunks=DAE.GridChunks((nx, ny), (256, 256)),
        ),
    )
    dsout = savedataset(outds_skeleton; path=outpath, skeleton=true, overwrite=true)
    forest = Cube(forpath)
    #masked = map(*, ds.layer, setchunks(forest,DiskArrays.eachchunk(ds.layer.chunks)))
    @time postprocess(ds.layer, dsout.defo, forest)
    @time PyramidScheme.buildpyramids(outpath)
end

# Open input data
#=
p = "/Net/Groups/BGI/work_5/scratch/fgans/germany_2020/"
outpath = "./output.zarr/"
orbits = readdir(p)
orbitname = map(o->split(basename(o),'_')[4],orbits)
d = DD.format(Dim{:orbit}(orbitname))
files = DD.DimArray(orbits,d)
ds = open_mfdataset(files)
#Prepare output dataset to write into, this might also be a view into an existing dataset
nx,ny = size(ds.layer)
outds_skeleton = Dataset(;defo=YAXArray((ds.X,ds.Y),Fill(UInt8(0),nx,ny),chunks=DAE.GridChunks((nx,ny),(256,256))))
dsout = savedataset(outds_skeleton,path=outpath,skeleton=true,overwrite=true)

#Call the postprocess function
postprocess(ds.layer,dsout.defo)

=#