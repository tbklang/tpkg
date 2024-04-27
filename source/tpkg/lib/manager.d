module tpkg.lib.manager;

// TODO: Need a ConfigEnrty-style API
// TODO: Make NikNaks have config entry?

import niknaks.config;
import std.container.slist : SList;

/** 
 * A package manager which
 * can resolve dependencies
 */
public class PackageManager
{
    private SList!(Source) sources;

    this()
    {

    }

    public void addSource(Source src)
    {
        this.sources.insertAfter(this.sources[], src);
    }

    public void removeSource(Source src)
    {
        this.sources.linearRemoveElement(src);
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