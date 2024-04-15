module tpkg.lib.docgen;

import tlang.compiler.symbols.data;
import tlang.compiler.symbols.containers;
import std.stdio;
import std.string : format;

public class DocumentGenerator
{
    private Program program;
    private File fileOut;

    // Writer state
    private bool listActive = false;

    this(File fileOut, Program program)
    {
        // TODO: Throw on unopened file
        this.fileOut = fileOut;
        this.program = program;
    }

    private void line(string text)
    {
        fileOut.writeln(text);
    }

    public void generate()
    {
        line("<html>");
        line("<body>");
        line(format("<h1>Program</h1>"));
        line("<h4>Program documentation</h4>");
        hr(fileOut);

        generateModuleListing(this.program);

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
    DocumentGenerator dg = new DocumentGenerator(testF, prog);

    dg.generate();
}