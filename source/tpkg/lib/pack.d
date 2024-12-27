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
 * Represents a package that one
 * is looking for. This is in
 * an un-fully realized state.
 */
public final class PackageCandidate
{
    private string name;
    private Version ver;
    private string ver_s;

    this(string name, Version ver)
    {
        this.name = name;
        this.ver = ver;

        this.ver_s = ver.repr();
    }

    public string getName()
    {
        return this.name;
    }

    public string getCmp() nothrow @safe
    {
        return name~":"~ver_s;
    }
    
    public override bool opEquals(Object other)
    {
        PackageCandidate other_pc = cast(PackageCandidate)other;
        if(other_pc is null)
        {
            return false;
        }

        import std.stdio : writeln;
        writeln("doing equals");

        return this.name == other_pc.name && this.ver.cmp(other_pc.ver) == 0;
    }

    override size_t toHash()  nothrow
    {
        string s = getCmp();
        size_t i = 0;
        foreach(char c; s)
        {
            i += c;
        }
        return i;
    }

    public override string toString()
    {
        import std.string : format;
        return format("PackageCandidate (%s/%s)", getName(), ver.repr());
    }
}

version(unittest)
{
    alias DV = DummyVersion;
    class DummyVersion : Version
    {
        private string ver_s;
        this(string ver)
        {
            this.ver_s = ver;
        }

        public long cmp(Version rhs)
        {
            return 0; // FIXME: Implement me
        }

        public string repr()
        {
            return ver_s;
        }
    }
}

unittest
{
    size_t[PackageCandidate] k;
    PackageCandidate pc1 = new PackageCandidate("A", new DV("0.0.1"));
    PackageCandidate pc2 = new PackageCandidate("A", new DV("0.0.1"));

    k[pc1] = 1;
    assert(k[pc2] == 1);

    assert(pc1 == pc2);
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