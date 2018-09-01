# Install dependencies needed to build the documentation.
empty!(LOAD_PATH)
push!(LOAD_PATH, @__DIR__, "@stdlib")
empty!(DEPOT_PATH)
pushfirst!(DEPOT_PATH, joinpath(@__DIR__, "deps"))
using Pkg
Pkg.instantiate()

using Documenter

# Include the `build_sysimg` file.

baremodule GenStdLib end
@isdefined(build_sysimg) || @eval module BuildSysImg
    include(joinpath(@__DIR__, "..", "contrib", "build_sysimg.jl"))
end

# Documenter Setup.

symlink_q(tgt, link) = isfile(link) || symlink(tgt, link)
cp_q(src, dest) = isfile(dest) || cp(src, dest)

# make links for stdlib package docs, this is needed until #522 in Documenter.jl is finished
const STDLIB_DOCS = []
const STDLIB_DIR = joinpath(@__DIR__, "..", "stdlib")
cd(joinpath(@__DIR__, "src")) do
    Base.rm("stdlib"; recursive=true, force=true)
    mkdir("stdlib")
    for dir in readdir(STDLIB_DIR)
        sourcefile = joinpath(STDLIB_DIR, dir, "docs", "src", "index.md")
        if isfile(sourcefile)
            targetfile = joinpath("stdlib", dir * ".md")
            push!(STDLIB_DOCS, (stdlib = Symbol(dir), targetfile = targetfile))
            if Sys.iswindows()
                cp_q(sourcefile, targetfile)
            else
                symlink_q(sourcefile, targetfile)
            end
        end
    end
end

# # Generate a suitable markdown file from NEWS.md and put it in src
# str = read(joinpath(@__DIR__, "..", "NEWS.md"), String)
# splitted = split(str, "<!--- generated by NEWS-update.jl: -->")
# @assert length(splitted) == 2
# replaced_links = replace(splitted[1], r"\[\#([0-9]*?)\]" => s"[#\g<1>](https://github.com/JuliaLang/julia/issues/\g<1>)")
# write(joinpath(@__DIR__, "src", "NEWS.md"), replaced_links)

const PAGES = [
    "Home" => "index.md",
    # hide("NEWS.md"),
    "Manual" => [
        "manual/getting-started.md",
        "manual/variables.md",
        "manual/integers-and-floating-point-numbers.md",
        "manual/mathematical-operations.md",
        "manual/complex-and-rational-numbers.md",
        "manual/strings.md",
        "manual/functions.md",
        "manual/control-flow.md",
        "manual/variables-and-scoping.md",
        "manual/types.md",
        "manual/methods.md",
        "manual/constructors.md",
        "manual/conversion-and-promotion.md",
        "manual/interfaces.md",
        "manual/modules.md",
        "manual/documentation.md",
        "manual/metaprogramming.md",
        "manual/arrays.md",
        "manual/missing.md",
        "manual/networking-and-streams.md",
        "manual/parallel-computing.md",
        "manual/running-external-programs.md",
        "manual/calling-c-and-fortran-code.md",
        "manual/handling-operating-system-variation.md",
        "manual/environment-variables.md",
        "manual/embedding.md",
        "manual/code-loading.md",
        "manual/profile.md",
        "manual/stacktraces.md",
        "manual/performance-tips.md",
        "manual/workflow-tips.md",
        "manual/style-guide.md",
        "manual/faq.md",
        "manual/noteworthy-differences.md",
        "manual/unicode-input.md",
    ],
    "Base" => [
        "base/base.md",
        "base/collections.md",
        "base/math.md",
        "base/numbers.md",
        "base/strings.md",
        "base/arrays.md",
        "base/parallel.md",
        "base/multi-threading.md",
        "base/constants.md",
        "base/file.md",
        "base/io-network.md",
        "base/punctuation.md",
        "base/sort.md",
        "base/iterators.md",
        "base/c.md",
        "base/libc.md",
        "base/stacktraces.md",
        "base/simd-types.md",
    ],
    "Standard Library" =>
        [stdlib.targetfile for stdlib in STDLIB_DOCS],
    "Developer Documentation" => [
        "devdocs/reflection.md",
        "Documentation of Julia's Internals" => [
            "devdocs/init.md",
            "devdocs/ast.md",
            "devdocs/types.md",
            "devdocs/object.md",
            "devdocs/eval.md",
            "devdocs/callconv.md",
            "devdocs/compiler.md",
            "devdocs/functions.md",
            "devdocs/cartesian.md",
            "devdocs/meta.md",
            "devdocs/subarrays.md",
            "devdocs/isbitsunionarrays.md",
            "devdocs/sysimg.md",
            "devdocs/llvm.md",
            "devdocs/stdio.md",
            "devdocs/boundscheck.md",
            "devdocs/locks.md",
            "devdocs/offset-arrays.md",
            "devdocs/require.md",
            "devdocs/inference.md",
        ],
        "Developing/debugging Julia's C code" => [
            "devdocs/backtraces.md",
            "devdocs/debuggingtips.md",
            "devdocs/valgrind.md",
            "devdocs/sanitizers.md",
        ]
    ],
]

for stdlib in STDLIB_DOCS
    @eval using $(stdlib.stdlib)
end

const render_pdf = "pdf" in ARGS
makedocs(
    build     = joinpath(@__DIR__, "_build", (render_pdf ? "pdf" : "html"), "en"),
    modules   = [Base, Core, BuildSysImg, [Base.root_module(Base, stdlib.stdlib) for stdlib in STDLIB_DOCS]...],
    clean     = true,
    doctest   = ("doctest=fix" in ARGS) ? (:fix) : ("doctest=true" in ARGS) ? true : false,
    linkcheck = "linkcheck=true" in ARGS,
    linkcheck_ignore = ["https://bugs.kde.org/show_bug.cgi?id=136779"], # fails to load from nanosoldier?
    strict    = true,
    checkdocs = :none,
    format    = render_pdf ? :latex : :html,
    sitename  = "The Julia Language",
    authors   = "The Julia Project",
    analytics = "UA-28835595-6",
    pages     = PAGES,
    html_prettyurls = ("deploy" in ARGS),
    html_canonical = ("deploy" in ARGS) ? "https://docs.julialang.org/en/v1/" : nothing,
    assets = ["assets/julia-manual.css", ]
)

# This overloads the function in Documenter that generates versions.js, to include
# v1/ in the version selector, instead of stable/.
#
# The function is identical to the version found in Documenter v0.19.6, except that
# it includes "v1" instead of "stable".
#
# Original:
# https://github.com/JuliaDocs/Documenter.jl/blob/v0.19.6/src/Writers/HTMLWriter.jl#L481-L506
#
import Documenter.Writers.HTMLWriter: generate_version_file
function generate_version_file(dir::AbstractString)
    named_folders = ["v1", "latest"]
    tag_folders = []
    for each in readdir(dir)
        each == "v1" && continue # skip the v1 symlink
        occursin(Base.VERSION_REGEX, each) && push!(tag_folders, each)
    end
    # sort tags by version number
    sort!(tag_folders, lt = (x, y) -> VersionNumber(x) < VersionNumber(y), rev = true)
    open(joinpath(dir, "versions.js"), "w") do buf
        println(buf, "var DOC_VERSIONS = [")
        for group in (named_folders, tag_folders)
            for folder in group
                println(buf, "  \"", folder, "\",")
            end
        end
        println(buf, "];")
    end
end

# Only deploy docs from 64bit Linux to avoid committing multiple versions of the same
# docs from different workers.
if "deploy" in ARGS && Sys.ARCH === :x86_64 && Sys.KERNEL === :Linux
    # Since the `.travis.yml` config specifies `language: cpp` and not `language: julia` we
    # need to manually set the version of Julia that we are deploying the docs from.
    ENV["TRAVIS_JULIA_VERSION"] = "nightly"

    deploydocs(
        julia = "nightly",
        repo = "github.com/JuliaLang/julia.git",
        target = "_build/html/en",
        dirname = "en",
        deps = nothing,
        make = nothing,
    )
end