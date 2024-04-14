module tpkg.app;

import std.stdio;
import tpkg.logging;


import jcli.commandgraph.cli;

void main(string[] arguments)
{
	DEBUG("Edit source/app.d to start your project.");

	/* Parse the command-line arguments */
    matchAndExecuteAcrossModules!(tpkg.commands)(arguments[1..arguments.length]);
}
