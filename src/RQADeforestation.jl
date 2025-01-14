module RQADeforestation
#__precompile__(false)
using Dates
using ArchGDAL: ArchGDAL as AG
using Glob
using YAXArrays
using Zarr
using Distributed: myid
using NetCDF

export gdalcube, rqatrend

include("auxil.jl")
include("rqatrend.jl")
include("analysis.jl")  # TODO what is still needed from analysis now that rqatrend is in its own file?
include("timestats.jl")


function main(tiles = ["E048N018T3"]; pol="VH", orbit="*", thresh=3.0)
    indir = "/eodc/products/eodc.eu/S1_CSAR_IWGRDH/SIG0/"
    continent = "EU"
    folders = ["V01R01","V0M2R4", "V1M0R1", "V1M1R1", "V1M1R2"]
    corruptedfiles = "corrupted_tiles.txt"
    # TODO save the corrupt files to a txt for investigation
    for tilefolder in tiles

        filenamelist = [glob("$(sub)/*$(continent)*20M/$(tilefolder)/*$(pol)_$(orbit)*.tif", indir) for sub in folders]

        allfilenames = collect(Iterators.flatten(filenamelist))


        relorbits = unique([split(basename(x), "_")[5][2:end] for x in allfilenames])
        @show relorbits
        for relorbit in relorbits
            for y in [2018,2019,2020,2021,2022, 2023]

            filenames = allfilenames[findall(contains("$(relorbit)_E"), allfilenames)]
            @time cube = gdalcube(filenames)

                path = joinpath(YAXDefaults.workdir[], "$(tilefolder)_rqatrend_$(pol)_$(relorbit)_thresh_$(thresh)_year_$(y)")
                @show path
                ispath(path*".done") && continue
                ispath(path*"_zerotimesteps.done") && continue

                tcube = cube[Time=Date(y-1, 7,1)..Date(y+1,7,1)]
                @show size(cube)
                @show size(tcube)
                if size(tcube, Ti) == 0
                    touch(path*"_zerotimesteps.done")
                    continue
                end
            try
                @time rqatrend(tcube; thresh, outpath=path * ".zarr", overwrite=true)
            catch e 
                
                if e.captured.ex isa ArchGDAL.GDAL.GDALError
                    println("Found GDALError:")
                    println(e.captured.ex.msg)
                   continue
                else 
                    rethrow(e)
                end
            end
                #=@everywhere begin
                    fname = "$(VERSION)_$(getpid())_$(time_ns()).heapsnapshot"
                    Profile.take_heap_snapshot(fname;streaming=true)
                end
                =#

                touch(path * ".done")
            end
        end
    end
end

end