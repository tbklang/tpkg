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

public abstract class Source
{
    protected string uri;

    this(string uri)
    {
        this.uri = uri;
    }

    public abstract bool searchPackages(string regex, ref Package[] found);
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
        this(Package[] dummyEntries)
        {
            super("dummy://");
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
    }
}

unittest
{
    PackageManager manager = new PackageManager();

    Package[] bogus = [new Package("tshell")];
    DummySource src = new DummySource(bogus);
    manager.addSource(src);

    Optional!(Package) res = manager.search("tsh*");
    assert(res.isPresent());
    Package res_p = res.get();
    assert(res_p);
    assert(res_p.getName() == "tshell");
}