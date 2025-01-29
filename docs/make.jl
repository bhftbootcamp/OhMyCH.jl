using OhMyCH
using Documenter

DocMeta.setdocmeta!(OhMyCH, :DocTestSetup, :(using OhMyCH); recursive = true)

makedocs(;
    modules = [OhMyCH],
    sitename = "OhMyCH.jl",
    format = Documenter.HTML(;
        repolink = "https://github.com/bhftbootcamp/OhMyCH.jl",
        canonical = "https://bhftbootcamp.github.io/OhMyCH.jl",
        edit_link = "master",
        assets = ["assets/favicon.ico"],
        sidebar_sitename = true,  # Set to 'false' if the package logo already contain its name
    ),
    pages = [
        "Home"    => "index.md",
        "API Reference" => "pages/api_reference.md",
        "Status codes" => "pages/constants.md",
        "For Developers" => "pages/advanced.md"
    ],
    warnonly = [:doctest, :missing_docs],
)

deploydocs(;
    repo = "github.com/bhftbootcamp/OhMyCH.jl",
    devbranch = "master",
    push_preview = true,
)
