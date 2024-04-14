module tpkg.logging;



// TODO: setup static logger here
import gogga;
import gogga.extras;
// TODO: May want gshared if it must be cross-thread module init
// as we would have many static fields init'd per thread then
// (would need a corresponding ghsraed field)


private GoggaLogger logger;
static this()
{
    logger = new GoggaLogger();
    logger.mode(GoggaMode.RUSTACEAN_SIMPLE);

    import dlog.basic : Level;
    logger.setLevel(Level.DEBUG);

    import dlog.basic : FileHandler;
    import std.stdio : stdout;
    logger.addHandler(new FileHandler(stdout));
}

mixin LoggingFuncs!(logger);