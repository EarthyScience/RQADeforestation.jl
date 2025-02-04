#!/usr/bin/env -S julia --color=yes --startup-file=no --threads=auto

using Pkg
using Glob: glob
using YAXArrays: YAXDefaults
using ArgParse
using RQADeforestation: gdalcube, rqatrend
using DimensionalData
using Dates: Date
using Distributed: addprocs, @everywhere

function parse_commandline()
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

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()

    pol = parsed_args["polarisation"]
    orbit = parsed_args["orbit"]
    thresh = parsed_args["threshold"]

    indir = parsed_args["in-dir"]
    readdir(indir) # check if inputdir is available

    if isdir(indir) && isempty(indir)
        @error "Input directory $indir must not be empty"
    end

    outdir = parsed_args["out-dir"]

    if isdir(outdir)
        @warn "Resume from existing output directory"
    else
        mkdir(outdir)
        @info "Write output to $outdir"
    end

    YAXDefaults.workdir[] = outdir

    continent = parsed_args["continent"]
    tile = parsed_args["tile"]

    pattern = "V*R*/EQUI7_$continent*20M/$tile/*"
    allfilenames = glob(pattern, indir) |> collect

    if length(allfilenames) == 0
        error("No input files found for given tile $tile")
    end

    relorbits = unique([split(basename(x), "_")[5][2:end] for x in allfilenames])
    y = parsed_args["year"]

    for relorbit in relorbits
        filenames = allfilenames[findall(contains("$(relorbit)_E"), allfilenames)]

        cube = gdalcube(filenames)
        path = joinpath(outdir, "$(tile)_rqatrend_$(pol)_$(relorbit)_thresh_$(thresh)_year_$(y)")

        ispath(path * ".done") && continue
        tcube = cube[Time=Date(y - 1, 7, 1) .. Date(y + 1, 7, 1)]

        rqatrend(tcube; thresh, outpath=path * ".zarr", overwrite=true)
    end
end

main()