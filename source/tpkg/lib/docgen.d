module tpkg.lib.docgen;

import tlang.compiler.symbols.data;
import tlang.compiler.symbols.containers;
import std.stdio;
import std.string : format;

public class DocumentGenerator
{
    private Program program;
    private string directory;

    // Current file being written to
    private File fileOut;

    // Writer state
    private bool listActive = false;

    // TOD: Take in a directory rather
    this(string directory, Program program)
    {
        this.directory = directory;
        this.program = program;
    }

    private void line(string text)
    {
        fileOut.writeln(text);
    }

    public void generate()
    {
        // Generate the front page (module listing)
        generateFrontPage(this.program);

        // Generate each module's page
        foreach(Module mod; this.program.getModules())
        {
            generateModulePage(mod);
        }
    }

    public void generateModulePage(Module mod)
    {
        openFile(format("%s.html", mod.getName()));

        scope(exit)
        {
            closeFile();
        }

        title(format("Module %s", mod.getName()));

    }

    private void title(string text)
    {
        // TODO: This should set <title> as well but maybe
        // in some seperate flush-later few buffer(s),
        // hence line() should be replaced with
        // a buffer that is flushed later
        line(format("<h1>%s</h1>", text));
    }

    private void openFile(string filename)
    {
        // TODO: bail if already open (means you didn't close)
        if(this.fileOut.isOpen())
        {
            throw new Exception("Cannot call openFile(string) if there is already a file open. This is a developer bug");
        }

        this.fileOut.open(this.directory~"/"~filename, "wb");
    }

    private void closeFile()
    {
        if(!this.fileOut.isOpen())
        {
            throw new Exception("Cannot call closeFile() if there is NO file open. This is a developer bug");
        }

        this.fileOut.flush();
        this.fileOut.close();
    }

    public void generateFrontPage(Program program)
    {
        openFile("index.html");

        scope(exit)
        {
            closeFile();
        }

        line("<html>");
        line("<body>");
        line(format("<h1>Program</h1>"));
        line("<h4>Program documentation</h4>");
        hr(fileOut);

        generateModuleListing(program);
    }

    private void hr(File fileOut)
    {
        line("<hr>");
    }

    public void generateModuleListing(Program program)
    {
        Module[] modules = program.getModules();
        line("<h2>Modules</h2>");
        line(format("<p>These are the <b>%d</b> modules available in the program.</p>", modules.length));
        
        listBegin();
        foreach(Module mod; modules)
        {
            item(format("%s at <i>%s</i>", link(mod.getName()~".html", mod.getName()), mod.getFilePath()));
        }
        listEnd();
        
    }

    private static string link(string to, string content)
    {
        return format("<a href=%s>%s</a>", to, content);
    }

    // If in list mode, makes it all a list item, else just
    // forwards directly to line
    private void item(string text)
    {
        if(this.listActive)
        {
            line("<li>"~text~"</li>");
            return;
        }

        line(text);
    }

    private void listBegin()
    {
        this.listActive = true;
        line("<ul>");
    }

    private void listEnd()
    {
        this.listActive = false;
        line("</ul>");
    }
}

version(unittest)
{
    import tlang.compiler.core : Compiler, gibFileData;
}

unittest
{
    File testF = File("out/index.html", "wb");

    // TODO: Fix this to have these locally available and not hardcoded to my machine's paths
    string inputFilePath = "../code/source/tlang/testing/modules/a.t";
    string sourceEntry = gibFileData(inputFilePath);

    
    Compiler c = new Compiler(sourceEntry, inputFilePath, File("/tmp/kak.bruh", "wb"));
    c.doLex();
    c.doParse();

    Program prog = c.getProgram();
    DocumentGenerator dg = new DocumentGenerator("out/", prog);

    dg.generate();
}