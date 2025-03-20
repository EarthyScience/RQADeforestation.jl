using RQADeforestation
using BenchmarkTools
using Glob
using DimensionalData
using Dates

tile = "E048N021T3"
continent = "EU"
#lim = Extent(X = (-63.36854472609895, -57.18529373390659), Y = (-2.666626089016638, -1.9161481184310643))
indir = "/eodc/products/eodc.eu/S1_CSAR_IWGRDH/SIG0/"
folders = ["V0M2R4", "V1M1R1", "V1M1R2"]
corruptedfiles = "corrupted_tiles.txt"
orbit = "A"
pol="VH"

filenamelist = [glob("$(sub)/*$(continent)*20M/$(tile)/*$(pol)_$(orbit)*.tif", indir) for sub in folders]

allfilenames = collect(Iterators.flatten(filenamelist))
relorbits = unique([split(basename(x), "_")[5] for x in allfilenames])
relorbit = relorbits[2]

filenames = allfilenames[findall(contains("$(relorbit)_E"), allfilenames)]
cube = gdalcube(filenames, :lazyagg)
tcube = cube[Time=Date(2021,7,1)..Date(2023,6,30)]
@benchmark RQADeforestation.rqatrend(tcube)
