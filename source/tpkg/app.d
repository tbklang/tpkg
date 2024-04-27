module tpkg.app;

import std.stdio;
import tpkg.logging;


import jcli.commandgraph.cli;
import niknaks.config : Registry;

import tpkg.commands;

void main(string[] arguments)
{
	DEBUG("Edit source/app.d to start your project.");

	// TODO: Setup registry and fill it up
	// with configuration
	Registry registry = Registry();
	tpkg.commands.reg = &registry;

	/* Parse the command-line arguments */
    matchAndExecuteAcrossModules!(tpkg.commands)(arguments[1..arguments.length]);
}
