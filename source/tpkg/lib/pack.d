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
    private Source from;
    private string name;
    private Version ver;
    private Package[] dependencies;

    this(Source from, string name)
    {
        assert(from);
        this.from = from;
        this.name = name;
    }

    public string getName()
    {
        return this.name;
    }

    public Source getSource()
    {
        return this.from;
    }
}


// public struct Dependency
// {
//     private 
// }