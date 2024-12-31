module tpkg.lib.manager;

// TODO: Need a ConfigEnrty-style API
// TODO: Make NikNaks have config entry?
import tpkg.logging;
import niknaks.config;
import std.container.slist : SList;
import niknaks.functional : Optional;
import std.string : format;
import tpkg.lib.exceptions;

import std.file : isDir, isFile, exists;
import std.path : expandTilde;
import std.exception : ErrnoException;
import std.file : FileException;
import std.zip;
import tpkg.lib.project : Project;
import std.stdio : File;
import std.string : format;
import std.path : buildPath, pathSplitter;
import niknaks.functional : Result, Optional, ok, error;
import tlang.compiler.core : CompileResult;
import tpkg.lib.pack : Package, Version, PackageCandidate, SearchResult;

// TODO: Move elsewhere
public struct StoreRef
{
    private string packDir;
    
    this(string packDir)
    {
        this.packDir = packDir;
    }

    public string getPackDir()
    {
        return this.packDir;
    }

    public string getDescrPath()
    {
        return buildPath(this.packDir, "t.pkg");
    }
}

// TODO: Move elsewhere
public struct FetchResult
{
    private PackageCandidate[] deps;
    private StoreRef root_sf;
    
    private this(StoreRef root_sf, PackageCandidate[] deps)
    {
        this.root_sf = root_sf;
        this.deps = deps;
    }

    public PackageCandidate[] dependencies()
    {
        return this.deps;
    }

    public StoreRef store()
    {
        return this.root_sf;
    }
}

/** 
 * A package manager which
 * can resolve dependencies
 */
public class PackageManager
{
    public static PackageManager fromConfiguration(string configPath)
    {
        configPath = expandTilde(configPath);

        if(!exists(configPath))
        {
            throw new TPkgException(format("The path to the package manager configuration at '%s' does not exist", configPath));
        }
        else if(!isFile(configPath))
        {
            throw new TPkgException(format("The path to the package manager configuration at '%s' does not refer to a file", configPath));
        }

        PackageManager pman = new PackageManager();

        import std.json;
        import std.stdio;
        import std.exception : ErrnoException;
        try
        {
            File configFile;
            configFile.open(configPath, "rb");
            byte[] data;
            data.length = configFile.size();
            data = configFile.rawRead(data);
            configFile.close();
            JSONValue config = parseJSON(cast(string)data);

            // TODO: Add sources here
        }
        catch(ErrnoException e)
        {
            throw new TPkgException(format("Error reading the config file: %s", e.msg));
        }
        catch(JSONException e)
        {
            throw new TPkgException(format("Error parsing the JSON config: %s", e.msg));
        }

        return pman;
    }

    private SList!(Source) sources;

    private string storePath;

    private bool allowPackagelessAddressing;
    private bool allowPackageAddressing;

    this()
    {
        this(expandTilde("~/.tpkg"));        
    }

    this(string storePath)
    {
        if(!exists(storePath))
        {
            throw new TPkgException(format("Invalid store path '%s': Path does not exist", storePath));
        }
        else if(!isDir(storePath))
        {
            throw new TPkgException(format("Invalid store path '%s': Not a directory", storePath));
        }

        this.storePath = storePath;

        // FIXME: Configuration
        this.allowPackagelessAddressing = false;
        this.allowPackageAddressing = true;
    }

    public void addSource(Source src)
    {
        this.sources.insertAfter(this.sources[], src);
    }

    public void removeSource(Source src)
    {
        this.sources.linearRemoveElement(src);
    }

    /** 
     * Unpacks the given package archive
     * into the data store
     *
     * Params:
     *   zar = the package archive
     *   name = the project's name
     * Returns: a storage descriptor
     */
    private StoreRef store(ZipArchive zar, string name)
    {
        ArchiveMember[string] ms = zar.directory();
        bool ignoreRootName = (format("%s/", name) in ms) !is null;
        DEBUG("ignoreRootName:", ignoreRootName);
        
        auto base = ignoreRootName ? buildPath(this.storePath) : buildPath(this.storePath, name);
        DEBUG(format("Storage path for %s: '%s'", name, base));
        
        string packDir = buildPath(this.storePath, name);

        File f;

        try
        {
            // clean up old package data (TODO: might want to version check prior to doing this)
            import std.file : rmdirRecurse, exists, isDir, timeLastModified;
            if(exists(packDir))
            {
                auto t_mod = timeLastModified(packDir);
                WARN(format("Found old directory for %s last modified at %s, removing...", name, t_mod));
                rmdirRecurse(packDir);
            }
            

            foreach(string m; ms.keys())
            {
                import std.string : endsWith;
                // Skip any directory-type entries
                if(endsWith(m, "/"))
                {
                    DEBUG(format("Skipping entry '%s' that is just a directory", m));
                    continue;
                }

                scope(exit)
                {
                    f.close();
                }

                ArchiveMember m_ent = ms[m];
                string m_path = buildPath(base, m);
                DEBUG("m_path:", m_path);

                
                if(!endsWith(m_path, "/")) // if it doesn't end in that, then recursively
                // create directories all the way up-to-but-not-including the entry itself
                // (last one must be a file with no trailing `/`)
                {
                    auto ps = pathSplitter(m_path);
                    ps.popBack();
                    string g = buildPath(ps);
                    DEBUG(format("Creating directory '%s' recursively...", g));
                    import std.file : mkdirRecurse;
                    mkdirRecurse(g);
                }

                DEBUG("m_path:", m_path);
                ubyte[] d = zar.expand(m_ent);
                
                f.open(m_path, "wb"); // TODO: Catch exceptions here
                f.rawWrite(d);
            }
        }
        catch(ErrnoException e)
        {
            throw new TPkgException
            (
                format
                (
                    "Error writing file '%s' to disk when unpacking for %s: %s",
                    f.name(),
                    name,
                    e
                )
            );
        }
        catch(FileException e)
        {
            throw new TPkgException
            (
                format
                (
                    "Error creating directory during unpack for %s: %s",
                    name,
                    e
                )
            );
        }


        return StoreRef(packDir);
    }

    public Result!(Optional!(StoreRef), string) lookup(PackageCandidate pc)
    {
        return lookup(pc.getName());
    }

    public Result!(Optional!(StoreRef), string) lookup(string name)
    {
        return lookup0(buildPath(this.storePath, name));
    }

    private Result!(Optional!(StoreRef), string) lookup0(string packDir)
    {
        // TODO: check if it is a file and then bail out with an error
        if(exists(packDir))
        {
            if(!isDir(packDir))
            {
                return error!(string, Optional!(StoreRef))
                (
                    format
                    (
                        "Failed to lookup, path '%s' does not refer to a directory",
                        packDir
                    )
                );
            }
            return ok!(Optional!(StoreRef), string)(Optional!(StoreRef)(StoreRef(packDir)));
        }
        else
        {
            return ok!(Optional!(StoreRef), string)(Optional!(StoreRef).empty());
        }
    }

    public Result!(Project, string) parse(StoreRef sr)
    {
        File f_descr;
        scope(exit)
        {
            f_descr.close();
        }

        import std.json : JSONValue, parseJSON, JSONException;

        try
        {
            f_descr.open(sr.getDescrPath());
            ubyte[] data;
            data.length = f_descr.size();
            data = f_descr.rawRead(data);
            string descr = cast(string)data;

            JSONValue json = parseJSON(descr);
            auto res = Project.deserialize(json);
            if(res.is_error())
            {
                return error!(string, Project)
                (
                    format
                    (
                        "Error validating the project descriptor at '%s': %s",
                        sr.getPackDir(),
                        res.error()
                    )
                );
            }

            return ok!(Project, string)(res.ok());
        }
        catch(ErrnoException e)
        {
            return error!(string, Project)
            (
                format
                (
                    "Error reading the project descriptor at '%s': %s",
                    sr.getPackDir(),
                    e.message
                )
            );
        }
        catch(JSONException e)
        {
            return error!(string, Project)
            (
                format
                (
                    "Error parsing the project descriptor at '%s': %s",
                    sr.getPackDir(),
                    e.message
                )
            );
        }
    }

    public void unstore(StoreRef p)
    {
        // string packDir = buildPath(this.storePath, p.getName());
        string packDir = p.getPackDir();
        DEBUG(format("Unstoring %s at pack dir '%s'...", p, packDir));

        try
        {
            import std.file : rmdirRecurse;
            rmdirRecurse(packDir);
        }
        catch(FileException e)
        {
            throw new TPkgException
            (
                format
                (
                    "Error unstoring package %s: %s",
                    p, // TODO: Fix error message text
                    e.message
                )
            );
        }

    }

    private struct BuildDep
    {
        private PackageCandidate pc;
        private StoreRef sr;

        this(PackageCandidate pc, StoreRef sr)
        {
            this.pc = pc;
            this.sr = sr;
        }

        public StoreRef store()
        {
            return this.sr;
        }
    }

    public Result!(CompileResult, string) build(FetchResult fr)
    {
        BuildDep[] deps;
        foreach(PackageCandidate dep_pc; fr.dependencies())
        {
            Result!(Optional!(StoreRef), string) dep_sr_res = lookup(dep_pc);
            if(dep_sr_res.is_error())
            {
                return error!(string, CompileResult)(format("Error looking up dependency '%s'", dep_pc.getName()));
            }

            Optional!(StoreRef) dep_sr_opt = dep_sr_res.ok();
            if(dep_sr_opt.isEmpty())
            {
                return error!(string, CompileResult)(format("Dependency '%s' not found", dep_pc.getName()));
            }

            StoreRef dep_sr = dep_sr_opt.get();
            deps ~= BuildDep(dep_pc, dep_sr);
        }
        DEBUG("BuildDeps: ", deps);

        // Build up the list of linking requests
        string[] links;
        foreach(BuildDep bd; deps)
        {
            StoreRef bd_sr = bd.store();
            Result!(Project, string) bd_p_res = parse(bd_sr);
            if(bd_p_res.is_error())
            {
                return error!(string, CompileResult)(bd_p_res.error());
            }

            Project bd_p = bd_p_res.ok();
            DEBUG(bd_p);
            foreach(string link; bd_p.getLinks())
            {
                links ~= buildPath(bd_sr.getPackDir(), link);
            }
        }
        DEBUG("Links are: ", links);

        // Storage reference of root package
        StoreRef root_sr = fr.store();
        Result!(Project, string) p_res = parse(root_sr);
        if(p_res.is_error())
        {
            return error!(string, CompileResult)(p_res.error());
        }

        Project p = p_res.ok();
        DEBUG(p);

        // FIXME: Implement compiling a library, perhaps
        // choosing ANY module file (a `.t` file) as the
        // entrypoint would work
        import tpkg.lib.project : ProjectType;
        if(p.getType() == ProjectType.LIBRARY)
        {
            return error!(string, CompileResult)("Cannot build a library YET");
        }

        string e_path = buildPath(root_sr.getPackDir(), p.getEntrypoint());
        DEBUG("Opening entrypoint file at '", e_path, "'...");

        import tlang.compiler.core : Compiler, forFile;
        Result!(Compiler, Exception) c_res = forFile(e_path);

        if(c_res.is_error())
        {
            return error!(string, CompileResult)(c_res.error().msg);
        }

        Compiler c = c_res.ok();

        if(links.length)
        {
            c.getConfig().addConfig("linker:link_files", links);
        }


        if(allowPackagelessAddressing)
        {
            // TODO: See if we even need the BuildDep instead of
            // just a StoreRef
            foreach(BuildDep build_dep; deps)
            {
                StoreRef build_dep_sr = build_dep.store();
                c.getModMan().addSearchPath(build_dep_sr.getPackDir());
            }            
        }

        if(allowPackageAddressing)
        {
            c.getModMan().addSearchPath(this.storePath);
        }
        



        import tlang.misc.exceptions : TError;

        try
        {
            CompileResult cmp_res = c.compile();
            INFO(format("Generated executable at '%s' in %d ms", cmp_res.createdFile, cmp_res.elapsedTime.total!("msecs")()));
            return ok!(CompileResult, string)(cmp_res);
        }
        catch(TError e)
        {
            ERROR(e);
            return error!(string, CompileResult)(e.msg);
        }
    }

    /** 
     * Fetches the package and stores
     * it in the package store
     *
     * Params:
     *   pc = the package candidate
     *   source = the source to fetch
     * from
     * Throws: 
     *   TPkgException on error fetching
     * the provided package or validating
     * it
     * Returns: a `FetchResult` which includes
     * a storage reference for the requested
     * package along with a list of all
     * dependencies resolved
     */
    public FetchResult fetch(PackageCandidate pc, Source source)
    {
        bool[PackageCandidate] map;
        scope(exit)
        {
            DEBUG("Full list of dependencies: ", map.keys());
        }

        StoreRef root_sf = fetch(pc, source, map);

        // remove root from dependency list
        map.remove(pc);

        return FetchResult(root_sf, map.keys());
    }

    private Result!(Optional!(StoreRef), string) resolveOffline(PackageCandidate pc)
    {
        Result!(Optional!(StoreRef), string) s_ref_res = lookup(pc);
        return s_ref_res;
    }

    private StoreRef resolveOnline(PackageCandidate pc, Source source)
    {
        ubyte[] data = source.fetch(pc); // TODO: Callback for progress of fetching
        DEBUG(format("Retrieved archive of %d bytes", data.length));

        import std.zip : ZipArchive, ZipException, ArchiveMember;
        
        try
        {
            ZipArchive zar = new ZipArchive(data);
            ArchiveMember[string] ents = zar.directory();
            version(unittest)
            {
                foreach(string ent; ents.keys())
                {
                    DEBUG(format("Found entry '%s'", ent));
                }
            }

            // Unpack the archive into the data store
            auto s_ref = store(zar, pc.getName());
            return s_ref;
        }
        catch(ZipException e)
        {
            throw new TPkgException
            (
                format
                (
                    "Error opening package archive for %s: %s",
                    pc,
                    e
                )
            );
        }
    }

    private StoreRef fetch
    (
        PackageCandidate pc,
        Source source,
        ref bool[PackageCandidate] map,
        bool offline = false
    )
    {
        

        StoreRef do_sr_get(PackageCandidate pc_in, Source src_in)
        {
            StoreRef s_ref_out;
            if(!offline)
            {
                s_ref_out = resolveOnline(pc_in, src_in);
            }
            else
            {
                Result!(Optional!(StoreRef), string) s_ref_res = resolveOffline(pc_in);
                // FIXME: Handle error above
                Optional!(StoreRef) s_ref_opt = s_ref_res.ok();
                // FIXME: Handle error above
                s_ref_out = s_ref_opt.get();
            }
            return s_ref_out;
        }

        // Obtain the storage reference according to the current online/offline
        // policy
        StoreRef s_ref = do_sr_get(pc, source); // TODO: handle error

        // From here onwards we are using a storage reference
        DEBUG(s_ref);

        // Validate package by attempting to
        // parse it
        auto l_res = parse(s_ref);
        if(l_res.is_error())
        {
            // Remove from store
            unstore(s_ref);

            throw new TPkgException
            (
                format
                (
                    "Error validating package %s: %s",
                    pc.getName(),
                    l_res.error()
                )
            );
        }

        Project l = l_res.ok();

        // Pool current node
        if((pc in map) is null)
        {
            map[pc] = false;
        }

        // Has it been visited?
        if(map[pc])
        {
            return s_ref;
        }

        // Mark as visited
        map[pc] = true;


        // Build out dependencies and fetch them as well
        foreach(string dep; l.getDependencies())
        {
            DEBUG("Searching for dependency '", dep, "'...");
            Optional!(SearchResult) dep_opt = search(dep);
            if(dep_opt.isEmpty())
            {
                ERROR("Could not find dependency '", dep, "'!");
                throw new TPkgException
                (
                    format
                    (
                        "Could not find dependency %s:",
                        pc.getName()
                    )
                );  
            }

            SearchResult sr = dep_opt.get();

            Source dep_src = sr.source();
            PackageCandidate dep_pc = sr.pack();

            // Pool current node
            if((dep_pc in map) is null)
            {
                map[dep_pc] = false;
            }

            // Has it been visited?
            if(map[dep_pc])
            {
                continue;
            }

            INFO("Fetching dependency '", dep, "'...");
            StoreRef dep_sr = fetch(dep_pc, dep_src, map, offline);
            Result!(Project, string) dep_p_res = parse(dep_sr); // TODO: Handle error
            assert(dep_p_res.is_okay()); // If fails, then somebody manipulated it whilst busy

            Project dep_p = dep_p_res.ok();
            DEBUG("Fetched dependency: ", dep_p);
        }


        return s_ref;
    }

    public Optional!(SearchResult) search(string regex)
    {
        // TODO: Return a list of candidates in future
        SearchResult[] matches;
        foreach(Source src; this.sources[])
        {
            SearchResult[] localFound;
            if(src.searchPackages(regex, localFound))
            {
                matches ~= localFound;
            }
            else
            {
                WARN
                (
                    format
                    (
                        "Could not find anything by '%s' @ %s",
                        regex,
                        src
                    )
                );
            }
        }

        return matches.length ? Optional!(SearchResult)(matches[0]) : Optional!(SearchResult).empty();
    }
}

public alias ProgressCallback = void delegate(ubyte[] got, size_t total);

public abstract class Source
{
    protected string uri;

    this(string uri)
    {
        this.uri = uri;
    }

    public abstract bool searchPackages(string regex, ref SearchResult[] found);

    public final ubyte[] fetch(PackageCandidate pc)
    {
        size_t got = 0;
        ubyte[] data;
        import progress; // TODO: Switch out to `niknaks.progress` (which I need to code)
        Bar b;
        void testProg(ubyte[] d, size_t total)
        {
            if(b is null)
            {
                b = new Bar();
                b.max = total;
                string m()
                {
                    return pc.getName();
                }
                b.message = &m;
            }

            data ~= d;
            size_t amount = d.length;
            b.next(amount);
            got += amount;
            if(got == total)
            {
                b.finish();
            }
        }

        try
        {
            DEBUG(format("Fetching %s...", pc));
            fetchImpl(pc, &testProg);
            
            return data;
        }
        catch(Exception e)
        {
            throw new TPkgException
            (
                format
                (
                    "Error whilst fetching '%s' from source %s: %s",
                    pc,
                    this,
                    e.msg
                )
            );
        }
    }

    protected abstract void fetchImpl(PackageCandidate pc, ProgressCallback onProgress);
}

unittest
{
    PackageManager manager = new PackageManager();

    Optional!(SearchResult) res = manager.search("tshell");
    assert(res.isEmpty());
}

version(unittest)
{
    class DummySource : Source
    {
        import std.regex;
        private PackageCandidate[] dummyEntries;

        this()
        {
            super("dummy://");
        }

        public void setEntries(PackageCandidate[] dummyEntries)
        {
            this.dummyEntries = dummyEntries;
        }

        public override bool searchPackages(string regex, ref SearchResult[] found)
        {
            // Loop over each entry and match on its name
            foreach(SearchResult ent; makeBogusSearchResults())
            {
                PackageCandidate ent_pc = ent.pack();
                RegexMatch!(string) m = matchAll(ent_pc.getName(), regex);
                DEBUG("Regex res: ", m);

                if(!m.empty())
                {
                    DEBUG(format("Matched '%s' to '%s'", ent_pc, regex));
                    found ~= ent;
                }
            }

            return cast(bool)found.length;
        }

        private SearchResult[] makeBogusSearchResults()
        {
            SearchResult[] s_r;
            foreach(PackageCandidate pc; this.dummyEntries)
            {
                s_r ~= new SearchResult(this, pc);
            }
            return s_r;
        }

        public override void fetchImpl(PackageCandidate pc, ProgressCallback clk)
        {
            string fetchURL = format("https://deavmi.assigned.network/git/tlang/%s/archive/master.zip", pc.getName());
            DEBUG("fetchURL: ", fetchURL);

            // TODO: Set timeout on both requests
            size_t chunkSize = 100;
            import std.net.curl : get, AutoProtocol, byChunk, byChunkAsync, HTTP;
            HTTP cl = HTTP(fetchURL);
            cl.method(HTTP.Method.head);
            cl.perform();
            string[string] hdrs = cl.responseHeaders();
            DEBUG("Performed head:", hdrs);
            import std.conv : to;
            size_t len = to!(size_t)(hdrs["content-length"]);

            foreach(ubyte[] c; byChunkAsync(fetchURL, chunkSize))
            {
                clk(c, len);
            }
        }
    }
}

version(unittest)
{
    import tpkg.lib.testing : DV;
}

unittest
{
    PackageManager manager = new PackageManager();

    DummySource src = new DummySource();
    PackageCandidate[] bogus =
    [
        new PackageCandidate("tshell", new DV("0.0.1")),
        new PackageCandidate("core",  new DV("0.0.1")),
        new PackageCandidate("cbind",  new DV("0.0.1"))
    ];
    src.setEntries(bogus);
    manager.addSource(src);

    // FIXME: The search should return almost a package "candidate"
    // this can then be provided to `fetch` which should actually
    // return a fully-populated `Package`
    Optional!(SearchResult) res = manager.search("tsh*");
    assert(res.isPresent());

    SearchResult sr = res.get();
    assert(sr);

    Source res_src = sr.source();
    assert(res_src is src);
    PackageCandidate res_pack = sr.pack();
    assert(res_pack);
    assert(res_pack.getName() == "tshell");


    FetchResult fetch_res = manager.fetch(res_pack, res_src);
    PackageCandidate[] resolved_deps = fetch_res.dependencies();
    import niknaks.arrays : isPresent;
    assert(isPresent(resolved_deps, new PackageCandidate("core", new DV("0.0.1"))));
    assert(isPresent(resolved_deps, new PackageCandidate("cbind", new DV("0.0.1"))));
    assert(resolved_deps.length == 2);

    manager.build(fetch_res);

    // TODO: Re-enable some of the below?
    // auto l_res = manager.lookup(res_pack);
    // assert(l_res.is_okay());
    // auto l_res_opt = l_res.ok();
    // DEBUG(l_res_opt);
    // assert(l_res_opt.isPresent());
    // manager.build(l_res_opt.get());
}

// TODO: Add another test with a better DummySoirce that
// doesn't require an internet connection

// unittest
// {
//     PackageManager manager = new PackageManager();

//     DummySource src = new DummySource();
//     Package[] bogus = [new Package(src, "core")];
//     src.setEntries(bogus);
//     manager.addSource(src);

//     Optional!(Package) res = manager.search("c*");
//     assert(res.isPresent());
//     Package res_p = res.get();
//     assert(res_p);
//     assert(res_p.getName() == "core");

//     manager.fetch(res_p);

//     auto l_res = manager.lookup(res_p);
//     assert(l_res.is_okay());
//     auto l_res_opt = l_res.ok();
//     DEBUG(l_res_opt);
//     assert(l_res_opt.isPresent());
//     manager.build(l_res_opt.get());
// }