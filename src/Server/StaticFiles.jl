# StaticFiles.jl — direct 1-1 port of Oxygen.jl's static-file serving,
# extended to also work with Therapy's static-site generator (`build`).
#
# Source files ported:
#   - Oxygen.jl/src/utilities/fileutil.jl  (getfiles, iteratefiles, mountfolder)
#   - Oxygen.jl/src/utilities/render.jl    (file)
#   - Oxygen.jl/src/core.jl                (staticfiles, dynamicfiles)
#
# Algorithm is byte-for-byte equivalent to Oxygen for the dev-server
# code path. The `App.static_mounts` book-keeping struct + the
# `copy_static_mounts!` helper is the Therapy-specific addition that
# lets `build()` materialise mounted files into `output_dir/` so the
# same `staticfiles(...)` declaration covers BOTH the dev server and
# the SSG output. Oxygen has no SSG so it has no equivalent.
#
# Conflict semantics — same as Oxygen:
#   page routes (app.routes)        ← matched first
#   static mounts (app.static_mounts) ← fallback
# Page routes always win on conflict. WebSocket upgrades and the
# Tailwind /styles.css special-case both happen even earlier in
# stream_handler (before either table is consulted).

using HTTP
using MIMEs

# ─── Internal helpers (ported from Oxygen) ───────────────────────────

"""
    _sf_getfiles(folder::String) -> Vector{String}

Return all files inside a folder (searches nested folders).
Direct port of Oxygen.jl/src/utilities/fileutil.jl `getfiles`.
"""
function _sf_getfiles(folder::String)
    target_files::Array{String} = []
    for (root, _, files) in walkdir(folder)
        for file in files
            push!(target_files, joinpath(root, file))
        end
    end
    return target_files
end

"""
    _sf_iteratefiles(func::Function, folder::String)

Walk through all files in a directory and apply a function to each file.
Direct port of Oxygen.jl/src/utilities/fileutil.jl `iteratefiles`.
"""
function _sf_iteratefiles(func::Function, folder::String)
    for filepath in _sf_getfiles(folder)
        func(filepath)
    end
end

"""
Helper that returns everything before a designated substring.
Direct port of Oxygen.jl/src/utilities/fileutil.jl `getbefore`.
"""
function _sf_getbefore(input::String, target)::String
    result = findfirst(target, input)
    index = first(result) - 1
    return input[begin:index]
end

"""
    mountfolder(folder::String, mountdir::String, addroute)

Discover files under `folder` and register each one under `mountdir`
via the user-supplied `addroute(currentroute, filepath)` callback.
Index.html files are also registered at the bare directory path
(e.g. `docs/index.html` → `/docs` AND `/docs/index.html`).

Direct port of Oxygen.jl/src/utilities/fileutil.jl `mountfolder`.
"""
function mountfolder(folder::String, mountdir::String, addroute)
    separator = Base.Filesystem.path_separator

    # track all registered paths
    paths = Dict{String, Bool}()

    _sf_iteratefiles(folder) do filepath
        # remove the first occurrence of the root folder from the filepath before "mounting"
        cleanedmountpath = replace(filepath, "$(folder)$(separator)" => "", count=1)

        # make sure to replace any system path separator with "/"
        cleanedmountpath = replace(cleanedmountpath, separator => "/")

        # generate the path to mount the file to
        mountpath = mountdir == "/" || isnothing(mountdir) || isempty(mountdir) || all(isspace, mountdir) ?
            "/$cleanedmountpath" :
            "/$mountdir/$cleanedmountpath"

        paths[mountpath] = true
        # register the file route
        addroute(mountpath, filepath)

        # also register file to the root of each subpath if this file is an index.html
        if endswith(mountpath, "/index.html")
            # add the route without the trailing "/index.html"
            bare_path = _sf_getbefore(mountpath, "/index.html")
            paths[bare_path] = true
            addroute(bare_path, filepath)
        end
    end
end

"""
    file(filepath::String; loadfile=nothing, status=200, headers=[]) -> HTTP.Response

Read a file and return an HTTP.Response. Content-Type is inferred from
the path extension via MIMEs.jl (defaults to `application/octet-stream`).

Direct port of Oxygen.jl/src/utilities/render.jl `file`.

# Arguments
- `filepath`: path to the file to read.
- `loadfile`: optional function to load the file. If not provided, the
  file is read from disk via `read(filepath, String)`.
- `status`: HTTP status code (default 200).
- `headers`: extra response headers (default `[]`).
"""
function file(filepath::String; loadfile = nothing, status::Int = 200, headers = [])::HTTP.Response
    has_loadfile    = !isnothing(loadfile)
    content         = has_loadfile ? loadfile(filepath) : read(filepath, String)
    content_length  = has_loadfile ? string(sizeof(content)) : string(filesize(filepath))
    content_type    = mime_from_path(filepath, MIME"application/octet-stream"()) |> contenttype_from_mime
    response = HTTP.Response(status, headers, body = content)
    HTTP.setheader(response, "Content-Type" => content_type)
    HTTP.setheader(response, "Content-Length" => content_length)
    return response
end

# ─── Therapy-side bookkeeping ────────────────────────────────────────
#
# A `StaticMount` is the single source of truth for one mounted file —
# the dev-server route handler and the SSG `build` step both read from
# it, so a user only declares `staticfiles(app, ...)` once.

mutable struct StaticMount
    mountpath::String                                  # URL path (e.g. "/static/app.js")
    filepath::String                                   # Disk path
    headers::Vector{Pair{String,String}}
    loadfile::Union{Function, Nothing}
    cached::Bool                                       # true = staticfiles, false = dynamicfiles
    cached_response::Union{HTTP.Response, Nothing}     # populated for cached mounts
end

"""
    serve_mount(mount::StaticMount, req::HTTP.Request) -> HTTP.Response

Used by the dev-server route handler. Returns the cached response if
the mount was registered via `staticfiles`; otherwise re-reads the
file from disk via `file(mount.filepath; ...)` (`dynamicfiles`).
"""
function serve_mount(mount::StaticMount, ::HTTP.Request)::HTTP.Response
    if mount.cached && mount.cached_response !== nothing
        return mount.cached_response
    end
    return file(mount.filepath;
        loadfile = mount.loadfile,
        headers  = mount.headers)
end

"""
    copy_static_mounts!(app, output_dir::String)

Used by `build(app)`. Walks every registered `StaticMount` and
materialises the file under `output_dir` at its mounted path, so
the SSG output contains the same `/static/foo.css` URL the dev
server serves. Skips bare-directory aliases (e.g. `/docs` for
`/docs/index.html`) — those URL aliases are dev-server-only; the
actual file already lives at `/docs/index.html`.

`loadfile` (if provided) is honoured: its return value is what
gets written to disk, matching dev-server behaviour.
"""
function copy_static_mounts!(app, output_dir::String)
    isempty(app.static_mounts) && return
    println("\nCopying static files...")
    seen_paths = Set{String}()
    for mount in app.static_mounts
        # Skip bare-directory aliases — the index.html they point to
        # has its own (canonical) entry that gets copied below.
        endswith(mount.filepath, "/index.html") &&
            !endswith(mount.mountpath, "/index.html") && continue
        mount.mountpath in seen_paths && continue
        push!(seen_paths, mount.mountpath)

        rel = lstrip(mount.mountpath, '/')
        out_path = joinpath(output_dir, rel)
        mkpath(dirname(out_path))
        if mount.loadfile === nothing
            cp(mount.filepath, out_path; force=true)
        else
            content = mount.loadfile(mount.filepath)
            write(out_path, content)
        end
        println("  $(mount.mountpath)")
    end
end

# ─── Public API (1-1 port of Oxygen's staticfiles / dynamicfiles) ───

# Shared body — staticfiles / dynamicfiles only differ in `cached`.
# Keeping the two public functions (matching Oxygen's API surface)
# but routing both through one implementation avoids duplicating the
# mount loop, header normalisation, and slash-stripping logic.
function _mount!(app, folder::String, mountdir::String,
                 headers::Vector, loadfile, cached::Bool)
    if !isempty(mountdir) && first(mountdir) == '/'
        mountdir = mountdir[2:end]
    end
    hdrs = Pair{String,String}[Pair{String,String}(string(p[1]), string(p[2])) for p in headers]
    function addroute(currentroute, filepath)
        resp = cached ? file(filepath; loadfile=loadfile, headers=hdrs) : nothing
        push!(app.static_mounts,
            StaticMount(currentroute, filepath, hdrs, loadfile, cached, resp))
    end
    mountfolder(folder, mountdir, addroute)
end

"""
    staticfiles(app, folder::String, mountdir::String="static";
                headers=[], loadfile=nothing)

Mount every file under `folder` as a GET route under `mountdir`.
File content is read ONCE at registration and the resulting
`HTTP.Response` is cached in the mount; serving a request just hands
back the precomputed response.

The `headers` vector is applied to every response (use it for
`Cache-Control`, `Access-Control-Allow-Origin`, etc.). The optional
`loadfile` callback transforms file content at registration time.

`build(app)` also picks these up and copies the files into
`output_dir/<mountpath>` so the SSG output mirrors the dev server.

Direct port of Oxygen.jl/src/core.jl `staticfiles`.

```julia
app = App(...)
staticfiles(app, joinpath(@__DIR__, "public"), "static";
            headers=["Cache-Control" => "public, max-age=3600"])
```
"""
staticfiles(app, folder::String, mountdir::String="static";
            headers::Vector=[], loadfile::Union{Function,Nothing}=nothing) =
    _mount!(app, folder, mountdir, headers, loadfile, true)

"""
    dynamicfiles(app, folder::String, mountdir::String="static";
                 headers=[], loadfile=nothing)

Same as [`staticfiles`](@ref) but files are RE-READ on every request,
so changes on disk show up without restarting the server. Use during
development; prefer `staticfiles` in production for the cached-response
fast-path.

Direct port of Oxygen.jl/src/core.jl `dynamicfiles`.
"""
dynamicfiles(app, folder::String, mountdir::String="static";
             headers::Vector=[], loadfile::Union{Function,Nothing}=nothing) =
    _mount!(app, folder, mountdir, headers, loadfile, false)
