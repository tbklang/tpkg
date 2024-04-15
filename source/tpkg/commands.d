module tpkg.commands;

import jcli;
import tpkg.logging;

import std.stdio : stdin;
import niknaks.mechanisms : Prompter, Prompt;
import tpkg.lib.project : Project;
import std.json;
import std.string : format;

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
        Prompter prompter = new Prompter(stdin);
        prompter.addPrompt(Prompt("Project name: "));
        prompter.addPrompt(Prompt("Project description: "));


        Prompt[] answers = prompter.prompt();

        Project proj;
        proj.setName(answers[0].getValue());
        proj.setDescription(answers[1].getValue());

        JSONValue json = proj.serialize();
        string jsonStr = json.toPrettyString();
        DEBUG(format("Generated project descriptor:\n%s", jsonStr));
    }
}