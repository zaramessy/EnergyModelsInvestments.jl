using Documenter

using EnergyModelsInvestments
const INV = EnergyModelsInvestments

# Copy the NEWS.md file
rm("src/manual/NEWS.md")
cp("../NEWS.md", "src/manual/NEWS.md")

makedocs(
    sitename = "EnergyModelsInvestments",
    format = Documenter.HTML(),
    modules = [EnergyModelsInvestments],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start" => "manual/quick-start.md",
            "Philosophy" => "manual/philosophy.md",
            "Example" => "manual/simple-example.md",
            "Release notes" => "manual/NEWS.md",
        ],
        "Library" => Any[
            "Public" => "library/public.md",
            "Internals" => "library/internals.md"
        ]
    ]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
