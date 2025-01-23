#!/usr/bin/env julia

using ArgParse
using RQADeforestation
using YAXArrays: YAXDefaults
using Glob
using IntervalSets
using Dates

function cli()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--threshold", "-t"
        help = "Threshold for the recurrence matrix computation"
        default = 3.0

        "--polarisation", "-p"
        help = "Polarisation that should be stacked"
        default = "VH"

        "--year", "-y"
        help = "Year in which the RQA Trend should be detected. 
        We take a buffer of six month before and after the year to end up with two years of data."
        default = 2018
        arg_type = Int

        "--orbit", "-o"
        help = "One of: Orbit number, 'A' for ascending, 'D' for descending, '*' for all orbits"
        default = "*"

        "--out-dir", "-d"
        help = "Path to output zarr dataset"
        default = "out.zarr"

        "in-dir"
        help = "Path to input"
        required = true

        "continent"
        help = "continent code for the tile to be processed"
        required = true

        "tile"
        help = "Tile id to be processed"
        required = true
    end

    args = parse_args(s)

    main(args["in-dir"], args["continent"], args["tile"];
        threshold=args["threshold"], polarisation=args["polarisation"],
        year=args["year"], orbit=args["orbit"], outdir=args["out-dir"]
    )
end


function main(indir, continent, tile; threshold=3.0, polarisation="VH", year=2018, orbit="*", outdir="out.zarr")
    readdir(indir) # check if inputdir is available

    if isdir(indir) && isempty(indir)
        @error "Input directory $indir must not be empty"
    end

    if isdir(outdir)
        @warn "Resume from existing output directory"
    else
        mkdir(outdir)
        @info "Write output to $outdir"
    end

    YAXDefaults.workdir[] = outdir

    pattern = "V*R*/EQUI7_$continent*20M/$tile/*"
    allfilenames = glob(pattern, indir) |> collect

    if length(allfilenames) == 0
        error("No input files found for given tile $tile")
    end

    relorbits = unique([split(basename(x), "_")[5][2:end] for x in allfilenames])

    for relorbit in relorbits
        filenames = allfilenames[findall(contains("$(relorbit)_E"), allfilenames)]

        cube = gdalcube(filenames)
        path = joinpath(outdir, "$(tile)_rqatrend_$(polarisation)_$(relorbit)_thresh_$(threshold)_year_$(year)")

        ispath(path * ".done") && continue
        tcube = cube[Time=Date(year, 1, 1) .. Date(year, 12, 31)]

        display(tcube)

        rqatrend(tcube; threshold, outpath=path * ".zarr", overwrite=true)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    cli()
end