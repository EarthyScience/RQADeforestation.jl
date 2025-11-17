using ArgParse
using YAXArrays: YAXDefaults
using ArchGDAL: ArchGDAL
using PyramidScheme
using AWSS3: global_aws_config, S3Path
using FilePathsBase: exists


#using YAXArrays, Zarr
using Minio: MinioConfig

global_aws_config(MinioConfig("http://s3.fairsendd.eodchosting.eu",region="us-east-1"))

const argparsesettings = ArgParseSettings()

ArgParse.parse_item(::Type{Date}, x::AbstractString) = Date(x)

@add_arg_table! argparsesettings begin
    "--threshold", "-t"
    help = "Threshold for the recurrence matrix computation"
    default = 3.0

    "--polarisation", "-p"
    help = "Polarisation that should be stacked"
    default = "VH"

    "--start-date"
    help = "Start date of the time series to analyze in ISO 8601 format YYYY-MM-DD"
    required = true
    arg_type = Date
    dest_name = "start_date"

    "--end-date"
    help = "End date of the time series to analyze in ISO 8601 format YYYY-MM-DD"
    required = true
    arg_type = Date
    dest_name = "end_date"

    "--orbit", "-o"
    help = "One of: Orbit number, 'A' for ascending, 'D' for descending, '*' for all orbits"
    default = "D"

    "--out-dir", "-d"
    help = "Path to output zarr dataset"
    default = "out.zarr"
    dest_name = "outdir"

    "--in-dir"
    help = "Path to input"
    required = true
    dest_name = "indir"

    "--continent"
    help = "continent code for the tile to be processed"
    required = true

    "--tiles", "--tile"
    help = "Tile id to be processed"
    required = true
    nargs = '+'
    arg_type = String

    "--folders", "--folder"
    help = "subfolders taken into account"
    default = ["V1M0R1", "V1M1R1", "V1M1R2"]
    arg_type = String
    nargs = '*'
end


function julia_main()::Cint
    main(; Dict(Symbol(k) => v for (k, v) in parse_args(argparsesettings))...)
    return 0
end


function main(;
    tiles,
    continent::String,
    indir::String,
    outstore=Zarr.S3Store("europe-forest-change"),
    outdir="results",
    tempfolder = S3Path(outstore.bucket, "intermediates/"),
    start_date::Date,
    end_date::Date,
    polarisation="VH",
    orbit="D",
    threshold=3.0,
    folders=["V1M0R1", "V1M1R1", "V1M1R2"],
    stack=:dae,
    postprocess=true,
    forestdir="data/forest20m_new",
    delete_intermediate=false
)
#global_aws_config(MinioConfig("http://s3.fairsendd.eodchosting.eu",region="us-east-1",username="ufew8gJku5hRY7VD6jbEjRi8VnvDfeEv",password="dqZdzWCLB7a9gTshL29AnQWGqL3krwnS"))
    in(orbit, ["A", "D"]) || error("Orbit needs to be either A or D")
    if isdir(indir) && isempty(indir)
        error("Input directory $indir must not be empty")
    end
    
    if isdir(tempfolder)
        @warn "Resume from existing output directory"
    else
        mkdir(tempfolder, recursive=true)
        @info "Write output to $outdir"
    end
    if monthday(start_date) != monthday(end_date)
        @warn "Selected time series does not include a multiple of whole years. This might introduce seasonal bias."
    end

    YAXDefaults.workdir[] = tempfolder
    @show typeof(tempfolder)

    corruptedfiles = open("corrupted_tiles.txt", "w")
    # TODO save the corrupt files to a txt for investigation
    for tilefolder in tiles
        @show tilefolder
        outpath = joinpath(outdir, "postprocess_$tilefolder.zarr/")
        @show outpath
        if outpath in Zarr.subdirs(outstore, outdir)
            println("Skip already processed tile $tilefolder")
            continue
        end
        sub = first(folders)
        #@show glob("$(sub)/*$(continent)*20M/$(tilefolder)*/*$(polarisation)_$(orbit)*.tif", indir)
        filenamelist = [glob("$(sub)/*$(continent)*20M/$(tilefolder)*/*$(polarisation)_$(orbit)*.tif", indir) for sub in folders]
        allfilenames = collect(Iterators.flatten(filenamelist))
        @show length(allfilenames)
        relorbits = unique([split(basename(x), "_")[5][2:end] for x in allfilenames])
        @show relorbits

        for relorbit in relorbits
            path = S3Path(joinpath(YAXDefaults.workdir[], "$(tilefolder)_rqatrend_$(polarisation)_$(orbit)$(relorbit)_thresh_$(threshold)_$(start_date)_$(end_date)"))
            #s3path = "s3://"*joinpath(outstore.bucket, path)
            @show path
            exists(path * ".done") && continue
            exists(path * "_zerotimesteps.done") && continue
            filenames = allfilenames[findall(contains("$(relorbit)_E"), allfilenames)]
            @time "cube construction" cube = gdalcube(filenames, stack)
            


            tcube = cube[Time=start_date .. end_date]
            @show size(cube)
            @show size(tcube)
            if size(tcube, 3) == 0
                touch(S3Path(path * "_zerotimesteps.done"))
                continue
            end
            try
                orbitoutpath = string(path * ".zarr/")
                # This is only necessary because overwrite=true doesn't work on S3 based Zarr files in YAXArrays
                # See https://github.com/JuliaDataCubes/YAXArrays.jl/issues/511
                if exists(S3Path(orbitoutpath))
                    println("Deleting path $orbitoutpath")    
                    rm(S3Path(orbitoutpath), recursive=true)
                end
                @show orbitoutpath
                # We save locally and then save a rechunked version in the cloud, 
                # because the chunking is suboptimal which we get from the automatic setting.
                tmppath = tempname() * ".zarr"
                @time "rqatrend" rqatrend(tcube; thresh=threshold, outpath=tmppath, overwrite=true)
                c = Cube(tmppath)
                @time "save to S3" savecube(setchunks(c, (15000,15000)), orbitoutpath)
                rm(tmppath, recursive=true)
                @show delete_intermediate
                if delete_intermediate == false
                    #PyramidScheme.buildpyramids(orbitoutpath)
                    Zarr.consolidate_metadata(orbitoutpath)
                end
            catch e
                println("inside catch")
                if hasproperty(e, :captured) && e.captured.ex isa ArchGDAL.GDAL.GDALError
                    msg = e.captured.ex.msg
                    corruptfile = split(msg, " ")[1][1:end-1]
                    corrupt_parts = split(corruptfile, "_")
                    foldername = corrupt_parts[end-1]
                    continentfolder = corrupt_parts[end-2]
                    corruptpath = joinpath(indir, foldername, "EQUI7_$continentfolder", tilefolder, corruptfile)
                    println("Corrupted input file")
                    println(corruptpath) 
                    println(joinpath(indir, ))
                    println(e.captured.ex.msg)
                    println(corruptedfiles, "Found GDALError:")
                    println(corruptedfiles, e.captured.ex.msg)
                    continue
                else
                    rethrow(e)
                end
            end
            donepath = path * ".done"
            @show donepath
            touch(S3Path(path * ".done"))
        end
        if postprocess
            @show outpath
            DD.STRICT_BROADCAST_CHECKS[] = false

            RQADeforestation.postprocess(tilefolder, tempfolder, outpath, forestdir)
            Zarr.consolidate_metadata(outpath)
            DD.STRICT_BROADCAST_CHECKS[] = true
            #base = basename(outpath)
            #@show base
            #command = `aws --endpoint-url http://s3.fairsendd.eodchosting.eu s3 cp --recursive $outpath s3://europe-forest-change/$base`

            #run(command)
        end
        if delete_intermediate
            rm(tempfolder, force=true, recursive=true)
        end


    end
end