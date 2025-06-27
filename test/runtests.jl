using RQADeforestation

# doctests do not run as testitem as of now, hence it is included here
using Documenter
DocMeta.setdocmeta!(
    RQADeforestation, :DocTestSetup, :(using RQADeforestation); recursive=true
)
doctest(RQADeforestation)

using TestItemRunner
@run_package_tests
