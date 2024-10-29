using RQADeforestation
using Documenter

DocMeta.setdocmeta!(RQADeforestation, :DocTestSetup, :(using RQADeforestation); recursive=true)

makedocs(;
    modules=[RQADeforestation],
    authors="Daniel Loos <dloos@bgc-jena.mpg.de> and contributors",
    sitename="RQADeforestation.jl",
    format=Documenter.HTML(;
        canonical="https://danlooo.github.io/RQADeforestation.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/EarthyScience/RQADeforestation.jl",
    devbranch="main",
)
