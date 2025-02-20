module tpkg.commands;

import jcli;
import tpkg.logging;

import std.stdio : stdin, File;
import tlang.compiler.symbols.data : Program;
import niknaks.mechanisms : Prompter, Prompt;
import tpkg.lib.project : Project;
import std.json;
import std.string : format;
import std.exception : ErrnoException;
import tpkg.lib.docgen;
import tlang.compiler.core : Compiler, gibFileData;
import niknaks.config : Registry;
import niknaks.arrays : unique;

public Registry* reg;

import niknaks.functional : Result, ok, error;

private mixin template BaseFunctions()
{
    private Result!(Project, string) openProject(string projectDirectory)
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
            return error!(string, Project)(format("Could not open/read project descriptor at %s: %s", f.name(), e));
        }

        JSONValue json;
        try
        {
            json = parseJSON(cast(string)descriptorFile);
            DEBUG(json.toPrettyString());
        }
        catch(JSONException e)
        {
            return error!(string, Project)(format("Could not parse project descriptor at %s: %s", f.name(), e));
        }
        
        return Project.deserialize(json);
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
        prompter.addPrompt(Prompt("Project name: ", false, false));
        prompter.addPrompt(Prompt("Project description: ", false, false));
        prompter.addPrompt(Prompt("Dependencies?: ", true));


        Prompt[] answers = prompter.prompt();

        Project proj;
        string projName;
        if(answers[0].getValue(projName))
        {
            proj.setName(projName);
        }
        else
        {
            ERROR("Could not get a valid project name");
            return;
        }
        string projDescription;
        if(answers[1].getValue(projDescription))
        {
            proj.setDescription(projDescription);
        }
        else
        {
            ERROR("Could not get a valid project description");
            return;
        }

        string[] projDeps;
        answers[2].getValues(projDeps);
        projDeps = unique(projDeps);
        DEBUG("Dependencies wanted: ", projDeps);
        proj.setDependencies(projDeps);
        
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

        auto res = openProject(directory);
        if(res.is_okay())
        {
            Project proj = res.ok();

            string inputFilePath = proj.getEntrypoint();
            string sourceEntry = gibFileData(inputFilePath);

            import std.datetime.stopwatch : StopWatch, AutoStart;
            StopWatch watch = StopWatch(AutoStart.no);
            watch.start();

            // Lex and parse
            Compiler c = new Compiler(sourceEntry, inputFilePath, File("/tmp/kak.bruh", "wb"));
            c.doLex();
            c.doParse();

            // Perform document generation on the given program
            Program prog = c.getProgram();
            DocumentGenerator dg = new DocumentGenerator(docDir, prog);
            dg.generate();

            INFO(format("Generated documentation in %s", watch.peek()));
        }
        else
        {
            ERROR("Could not generate documentation");
        }
        
        
    }
}

private mixin template RequiresConfig()
{
    @ArgNamed("config", "Path to the package manager configuration")
    @(ArgConfig.optional)
    string config = "~/.tpkg/config.json";
}
import tpkg.lib.manager;
import niknaks.functional : Optional;
import tpkg.lib.pack : Package, SearchResult;

@Command("search", "Search for a package")
struct SearchCommand
{
    mixin RequiresConfig!();

    @ArgPositional("search term", "The regular expression to search by")
    string regex;

    void onExecute()
    {
        PackageManager pman = PackageManager.fromConfiguration(config);

        // TODO: This should return a list in actuality
        Optional!(SearchResult) res = pman.search(regex);

        if(res.isEmpty())
        {
            ERROR(format("No packages found with search term '%s'", regex));
        }
    }
}