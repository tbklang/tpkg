module tpkg.lib.testing;

import tpkg.lib.pack : Version;

public alias DV = DummyVersion;
public class DummyVersion : Version
{
    private string ver_s;
    this(string ver)
    {
        this.ver_s = ver;
    }

    public long cmp(Version rhs)
    {
        return ver_s == rhs.repr() ? 0 : -1; // FIXME: Implement me
        // return 0; 
    }

    public string repr()
    {
        return ver_s;
    }
}