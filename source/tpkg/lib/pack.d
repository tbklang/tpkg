module tpkg.lib.pack;

// TODO: make comprable
public interface Version
{
    // TODO: make the below opCmp 
    public long cmp(Version rhs);
    public string repr();
}

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
    private string name;
    private Version ver;
    private Package[] dependencies;
}


// public struct Dependency
// {
//     private 
// }