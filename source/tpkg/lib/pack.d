module tpkg.lib.pack;

// TODO: make comprable
public interface Version
{
    // TODO: make the below opCmp 
    public long cmp(Version rhs);
    public string repr();
}

import tpkg.lib.manager : Source;

// This would be a package entry,
// with a name, version and list
// of dependencies
//
// Multiple packages with the
// same name can exist, they
// would, however, differ by
// their version and potentially
// also their dependencies
public class Package
{
    private Source from; // FIXME: Remove this
    private string name;
    private Version ver;
    private Package[] dependencies;

    this(Source from, string name)
    {
        this(from, name, []);
    }

    this(Source from, string name, Package[] dependencies)
    {
        assert(from);
        this.from = from;
        this.name = name;
        this.dependencies = dependencies;
    }

    public string getName()
    {
        return this.name;
    }

    // FIXME: Remove this
    public Source getSource()
    {
        return this.from;
    }

    public Package[] getDependencies()
    {
        return this.dependencies;
    }
}

/** 
 * Represents a candidiate returned
 * after performing a package search
 */
public final class PackageCandidate
{
    private Source from;
    private string name;
    private Version ver;

    this(Source from, string name, Version ver)
    {
        assert(from);
        this.from = from;
        this.name = name;
        this.ver = ver;
    }

    public string getName()
    {
        return this.name;
    }

    public Source getSource()
    {
        return this.from;
    }

    public string getCmp()
    {
        return name~":"~ver.repr();
    }

    // override size_t toHash() nothrow
    // {
    //     size_t i = 0;
    //     foreach(char c; getCmp())
    //     {
    //         i += c;
    //     }

    //     return i;
    // }
}

/** 
 * The result of a search
 * which combines the package
 * found along with the source
 * whereby it was found in
 */
public final class SearchResult
{
    private Source s;
    private PackageCandidate p;

    this(Source source, PackageCandidate pack)
    {
        this.s = source;
        this.p = pack;
    }

    public Source source()
    {
        return this.s;
    }

    public PackageCandidate pack()
    {
        return this.p;
    }
}