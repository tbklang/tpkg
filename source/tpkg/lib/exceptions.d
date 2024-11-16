module tpkg.lib.exceptions;

public final class TPkgException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}