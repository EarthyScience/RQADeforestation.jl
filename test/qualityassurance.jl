@testitem "qualityassurance" begin
    using Aqua
    using Dates
    using ArgParse

    Aqua.test_all(
        RQADeforestation;
        stale_deps=(;ignore=[:Proj, :TimeseriesSurrogates, :KML]),
        piracies=(;treat_as_own=[ArgParse.parse_item]),
        # persistent_tasks tests time of importing the package,
        # which is not nice, because of all the drivers load on their __init__ time
        # hence we turn it off
        persistent_tasks=false,
    )
end