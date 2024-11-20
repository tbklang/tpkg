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
    }

    public void addSource(Source src)
    {
        this.sources.insertAfter(this.sources[], src);
    }

    public void removeSource(Source src)
    {
        this.sources.linearRemoveElement(src);
    }

    import std.zip;
    import tpkg.lib.project : Project;
    import std.stdio : File;
    import std.string : format;
    import std.path : buildPath, pathSplitter;

    private struct StoreRef
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

    import niknaks.functional : Result, Optional, ok, error;

    public Result!(Optional!(Project), string) lookup(string name)
    {
        return lookup0(buildPath(this.storePath, name~".tpkg"));
    }

    private Result!(Optional!(Project), string) lookup0(string descriptorPath)
    {
        if(!exists(descriptorPath))
        {
            return ok!(Optional!(Project), string)(Optional!(Project).empty());
        }

        File f_descr;
        scope(exit)
        {
            f_descr.close();
        }

        import std.json : JSONValue, parseJSON, JSONException;

        try
        {
            f_descr.open(descriptorPath);
            ubyte[] data;
            data.length = f_descr.size();
            data = f_descr.rawRead(data);
            string descr = cast(string)data;

            JSONValue json = parseJSON(descr);
            Project projOut;
            auto res = Project.deserialize(json);
            if(res.is_error())
            {
                return error!(string, Optional!(Project))
                (
                    format
                    (
                        "Error validating the project descriptor at '%s': %s",
                        f_descr.name(),
                        res.error()
                    )
                );
            }

            return ok!(Optional!(Project), string)(Optional!(Project)(projOut));
        }
        catch(ErrnoException e)
        {
            return error!(string, Optional!(Project))
            (
                format
                (
                    "Error reading the project descriptor at '%s': %s",
                    f_descr.name(),
                    e
                )
            );
        }
        catch(JSONException e)
        {
            return error!(string, Optional!(Project))
            (
                format
                (
                    "Error parsing the project descriptor at '%s': %s",
                    f_descr.name(),
                    e
                )
            );
        }
    }

    public void unstore(Package p)
    {
        string packDir = buildPath(this.storePath, p.getName());
        DEBUG("Unstoring %s at pack dir '%s'...", p, packDir);

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
                    p.getName(),
                    e.message
                )
            );
        }

    }

    public void build(Package p)
    {
        fetch(p); // fetch, store, parse+validate


        // look
    }

    /** 
     * Fetches the package and stores
     * it in the package store
     *
     * Params:
     *   p = the package
     * Throws: 
     *   TPkgException on error fetching
     * the provided package
     */
    public void fetch(Package p)
    {
        Source s = p.getSource();
        ubyte[] data = s.fetch(p); // TODO: Callback for progress of fetching
        DEBUG(format("Retrieved archive of %d bytes", data.length));

        import std.uuid : randomUUID;
        string name = randomUUID().toString();
        // FIXME: For windows this should be a valid path

        import std.zip : ZipArchive, ZipException, ArchiveMember;
        
        bool isRoot(string name)
        {
            import std.string : split;
            string[] c = split(name, "/");
            return c.length == 2 ? c[1].length == 0 : false;
        }

        import niknaks.arrays : filter;
        import niknaks.functional : Predicate, predicateOf;

        bool hasOnlyRoot(ArchiveMember[string] m)
        {
            string[] o;
            filter!(string)(m.keys(), predicateOf!(isRoot), o);
            DEBUG(o);
            return o.length == 1;
        }
        

        import std.json : JSONException;
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
            auto s_ref = store(zar, p.getName());
            DEBUG(s_ref);

            // Validate package by looking it up
            auto l_res = lookup0(s_ref.getDescrPath());
            if(l_res.is_error())
            {
                // Remove from store
                unstore(p);

                throw new TPkgException
                (
                    format
                    (
                        "Error validating package %s: %s",
                        p.getName(),
                        l_res.error()
                    )
                );
            }

            
        }
        catch(ZipException e)
        {
            throw new TPkgException
            (
                format
                (
                    "Error opening package archive for %s: %s",
                    p,
                    e
                )
            );
        }
    }

    public Optional!(Package) search(string regex)
    {
        // TODO: Return a list of candidates in future
        Package[] matches;
        foreach(Source src; this.sources[])
        {
            Package[] localFound;
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

        return matches.length ? Optional!(Package)(matches[0]) : Optional!(Package).empty();
    }
}

// public enum SourceKind
// {
//     LOCAL,
//     HTTP
// }

import tpkg.lib.pack : Package, Version;

public alias ProgressCallback = void delegate(ubyte[] got, size_t total);

public abstract class Source
{
    protected string uri;

    this(string uri)
    {
        this.uri = uri;
    }

    public abstract bool searchPackages(string regex, ref Package[] found);

    public final ubyte[] fetch(Package p)
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
                    return p.getName();
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
            DEBUG(format("Fetching %s...", p));
            fetchImpl(p, &testProg);
            
            return data;
        }
        catch(Exception e)
        {
            throw new TPkgException
            (
                format
                (
                    "Error whilst fetching '%s' from source %s: %s",
                    p,
                    this,
                    e.msg
                )
            );
        }
    }

    protected abstract void fetchImpl(Package p, ProgressCallback onProgress);
}

// public struct Source
// {
//     private SourceKind kind;
//     private string uri;

//     this(string uri, SourceKind kind)
//     {
//         this.uri = uri;
//         this.kind = kind;
//     }
// }


unittest
{
    PackageManager manager = new PackageManager();

    Optional!(Package) res = manager.search("tshell");
    assert(res.isEmpty());
}

version(unittest)
{
    class DummySource : Source
    {
        import std.regex;
        private Package[] dummyEntries;

        this()
        {
            super("dummy://");
        }

        public void setEntries(Package[] dummyEntries)
        {
            this.dummyEntries = dummyEntries;
        }

        public override bool searchPackages(string regex, ref Package[] found)
        {
            // Loop over each entry and match on its name
            foreach(Package ent; this.dummyEntries)
            {
                RegexMatch!(string) m = matchAll(ent.getName(), regex);
                DEBUG("Regex res: ", m);

                if(!m.empty())
                {
                    DEBUG(format("Matched '%s' to '%s'", ent, regex));
                    found ~= ent;
                }
            }

            return cast(bool)found.length;
        }

        public override void fetchImpl(Package p, ProgressCallback clk)
        {
            // TODO: Set timeout on both requests
            size_t chunkSize = 100;
            import std.net.curl : get, AutoProtocol, byChunk, byChunkAsync, HTTP;
            HTTP cl = HTTP("https://deavmi.assigned.network/git/deavmi/tshell/archive/master.zip");
            cl.method(HTTP.Method.head);
            cl.perform();
            string[string] hdrs = cl.responseHeaders();
            DEBUG("Performed head:", hdrs);
            import std.conv : to;
            size_t len = to!(size_t)(hdrs["content-length"]);

            foreach(ubyte[] c; byChunkAsync("https://deavmi.assigned.network/git/deavmi/tshell/archive/master.zip", chunkSize))
            {
                clk(c, len);
            }
        }
    }
}

unittest
{
    PackageManager manager = new PackageManager();

    DummySource src = new DummySource();
    Package[] bogus = [new Package(src, "tshell")];
    src.setEntries(bogus);
    manager.addSource(src);

    Optional!(Package) res = manager.search("tsh*");
    assert(res.isPresent());
    Package res_p = res.get();
    assert(res_p);
    assert(res_p.getName() == "tshell");

    manager.fetch(res_p);
}