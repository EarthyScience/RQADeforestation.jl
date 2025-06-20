using RQADeforestation
using BenchmarkTools
using Glob
import Pkg: Artifacts.@artifact_str, ensure_artifact_installed

ensure_artifact_installed("rqatestdata", "Artifacts.toml")
testdatapath = joinpath(artifact"rqatestdata", "RQADeforestationTestData-2.0")

testdir = tempname()
rm(testdir, recursive=true, force=true)
mkpath(testdir)


filenames = glob("*/*/*/*.tif",testdatapath)
cube = gdalcube(filenames)
@benchmark RQADeforestation.rqatrend(cube)