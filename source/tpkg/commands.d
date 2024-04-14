module tpkg.commands;

import jcli;
import tpkg.logging;

import std.stdio : stdin;

private mixin template BaseCommands()
{
    @ArgPositional("directory", "The directory to run in")
    string directory;
}

@Command("init", "Initializes a new project")
struct InitCommand
{
    mixin BaseCommands!();



    void onExecute()
    {
        DEBUG("Command directory: ", directory);
        DEBUG("Julle");


        // TODO: Prompt project information here
    }
}