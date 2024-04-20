module tpkg.commands;

import jcli;
import tpkg.logging;

import std.stdio : stdin;
import niknaks.mechanisms : Prompter, Prompt;
import tpkg.lib.project : Project;
import std.json;
import std.string : format;
import std.exception : ErrnoException;
import tpkg.lib.docgen;

private mixin template BaseFunctions()
{
    private bool openProject(string projectDirectory, ref Project proj)
    {
        import std.stdio;

        File f;
        scope(exit)
        {
            f.close();
        }

        byte[] descriptorFile;

        try
        {
            f.open(projectDirectory~"/t.pkg", "rb");
            descriptorFile.length = f.size();
            f.rawRead(descriptorFile);
        }
        catch(ErrnoException e)
        {
            ERROR(format("Could not open/read project descriptor at %s: %s", f.name(), e));
            return false;
        }

        // TODO: Read project descriptor and THEN determine the entry point from
        // that

        JSONValue json;
        try
        {
            json = parseJSON(cast(string)descriptorFile);
            DEBUG(json);
        }
        catch(JSONException e)
        {
            ERROR(format("Could not parse project descriptor at %s: %s", f.name(), e));
            return false;
        }
        
        
        proj = Project.deserialize(json);

        return true;
    }
}

private mixin template BaseCommands()
{
    // TODO: detec current dir as default
    @ArgPositional("directory", "The directory to run in")
    @(ArgConfig.optional)
    string directory = ".";
}

@Command("init", "Initializes a new project")
struct InitCommand
{
    mixin BaseCommands!();
    mixin BaseFunctions!();


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

@Command("doc", "Generates documentation for the project")
struct DocGenCommand
{
    mixin BaseCommands!();
    mixin BaseFunctions!();

    @ArgNamed("output", "The directory where the doc files should be written to")
    @(ArgConfig.optional)
    string docDir = "doc";

    void onExecute()
    {
        
        DEBUG(format("Base project directory '%s'", directory));
        DEBUG(format("Output directory for docs '%s'", docDir));

        Project proj;
        if(openProject(directory, proj))
        {
            // DocumentGenerator dg = new DocumentGenerator(docDir);
        }
        else
        {
            ERROR("Could not generate documentation");
        }
        
    }
}