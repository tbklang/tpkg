module tpkg.lib.docgen;

import tlang.compiler.symbols.data;
import tlang.compiler.symbols.containers;
import std.stdio;
import std.string : format;
import std.conv : to;
import std.string : stripRight;

private struct ParamTable
{
    private VariableParameter[] params;

    private static paramToRow(VariableParameter param)
    {
        string comment = "TODO: Implement me";

        string s = "<tr>";
        
        s ~= format("<td>%s</td><td>%s</td>", param.getName(), comment);

        s ~= "</tr>";

        return s;
    }

    public void addParam(VariableParameter param)
    {
        this.params ~= param;
    }

    public string serialize()
    {
        if(!this.params)
        {
            return "";
        }
        
        string s = "<table>";

        s ~= "<thead>";
        s ~= "<tr><th>Parameter</th><th>Description</th></tr>";
        s ~= "</thead>";

        foreach(VariableParameter param; this.params)
        {
            s ~= paramToRow(param);
        }

        s ~= "</table>";

        return s;
    }
}

private struct HeaderInfo
{
    private string title;
    private string description;


    private string extra;

    public void setExtra(string extra)
    {
        this.extra = extra;
    }


    private string[string] links;

    public void addLink(string name, string link)
    {
        this.links[name] = link;
    }

    private static string genLink(string name, string link)
    {
        return format(`<a href="%s">%s</a>`, link, name);
    }

    private string genLinks()
    {
        if(!this.links)
        {
            return "";
        }

        string nav;
        foreach(string name; this.links.keys())
        {
            nav ~= genLink(name, this.links[name]);
        }
        return format("<nav>%s</nav>", nav);
    }

    public string serialize()
    {
        string bdy;

        bdy = format("<html>\n<head>\n\t<title>%s</title>\n%s\n</head>\n", this.title, this.extra);

        bdy ~= format("<body>\n\t<header><h1>%s</h1>\n\t<h4>%s</h4>%s</header>", this.title, this.description, genLinks());

        bdy ~= "<br>\n";

        return bdy;
    }
}

private struct DocState
{
    private HeaderInfo hdr;
    
    public void makeHeader(string title, string description)
    {
        this.hdr = HeaderInfo(title, description);

        // Set sakura CSS
        // this.hdr.setExtra(`<link rel="stylesheet" href="https://unpkg.com/sakura.css/css/sakura.css" type="text/css">`);
        
        // Set Simple.css
        this.hdr.setExtra(`<link rel="stylesheet" href="https://cdn.simplecss.org/simple.min.css">`);
    }

    private string bdy;

    public void appendLine(string line)
    {
        this.bdy ~= format("%s\n", line);
    }

    public void addLink(string name, string to)
    {
        this.hdr.addLink(name, to);
    }

    public string serialize()
    {
        return this.hdr.serialize()~this.bdy~"\n</body>\n</html>";
    }
}


public class DocumentGenerator
{
    private Program program;
    private string directory;

    // Current file being written to
    private File fileOut;
    private DocState state;

    // Writer state
    private bool listActive = false;

    // TOD: Take in a directory rather
    this(string directory, Program program)
    {
        this.directory = directory;
        this.program = program;
    }

    private void addLink(string name, string to)
    {
        this.state.addLink(name, to);
    }

    private void line(string text)
    {
        // fileOut.writeln(text);
        this.state.appendLine(text);
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

        title(format("Module %s", mod.getName()), format("At file %s", mod.getFilePath()));

        spacer();
        spacer();

        // Emit all functions
        line("<h3>Functions</h3>");
        line("<p>All publically visible methods</p>");
        bool onlyFuncs(Statement s) { return cast(Function)s !is null; }
        Statement[] funcs;
        filter!(Statement)(mod.getStatements(), predicateOf!(onlyFuncs), funcs);
        foreach(Statement stmt; funcs)
        {
            Function func = cast(Function)stmt;
            // TODO: Ensure only PUBLIC methods listed
            generateFunctionBlock(func);
        }

        // Emit all variables
        line("<h3>Variable</h3>");
        line("<p>All publically visible variables</p>");
        bool onlyVars(Statement s) { return cast(Variable)s !is null; }
        Statement[] vars;
        filter!(Statement)(mod.getStatements(), predicateOf!(onlyVars), vars);
        foreach(Statement stmt; vars)
        {
            Variable var = cast(Variable)stmt;
            // TODO: Ensure only PUBLIC methods listed
            generateVariableBlock(var);
        }

    }

    private void generateVariableBlock(Variable var)
    {

    }

    import niknaks.arrays : filter;
    import niknaks.functional : predicateOf, Predicate;

    private void spacer()
    {
        line("<div></div>");
    }

    private void generateFunctionBlock(Function func)
    {
        Comment comment = func.getComment();
        string commentStr = comment is null ? "<i>No description</i>" : format("<pre>%s</pre>", comment.getContent());

        ParamTable table;
        VariableParameter[] params = func.getParams();

        string paramText;
        foreach(VariableParameter param; params)
        {
            paramText ~= format("%s %s, ", param.getType(), param.getName());
            table.addParam(param);
        }
        paramText = stripRight(paramText, " ,");

        openBlock();
        scope(exit)
        {
            closeBlock();
        }

        line(format("<h4><mark>%s</mark> %s<i>(%s)</i></h4>", func.getType(), func.getName(), paramText));
        line(commentStr);
        line(table.serialize());
        line(format("<p><b>Returns:</b> <code>%s</code><p>", func.getType()));
    }

    private void openBlock()
    {
        line("<article>");
    }

    private void closeBlock()
    {
        line("</article>");
    }

    private void title(string title, string description)
    {

        this.state.makeHeader(title, description);

    }

    private void openFile(string filename)
    {
        // TODO: bail if already open (means you didn't close)
        if(this.fileOut.isOpen())
        {
            throw new Exception("Cannot call openFile(string) if there is already a file open. This is a developer bug");
        }

        // Open output file
        this.fileOut.open(this.directory~"/"~filename, "wb");

        // Clear doc state
        this.state = DocState();
    }

    private void closeFile()
    {
        if(!this.fileOut.isOpen())
        {
            throw new Exception("Cannot call closeFile() if there is NO file open. This is a developer bug");
        }

        // Flush out the header info
        this.fileOut.writeln(this.state.serialize());
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

        title("Program", "Program documentation");
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
            string modPageLink = mod.getName()~".html";
            addLink(mod.getName(), modPageLink);
            item(format("%s at <i>%s</i>", link(modPageLink, mod.getName()), mod.getFilePath()));
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
    // string inputFilePath = "../code/source/tlang/testing/modules/a.t";
    string inputFilePath = "../code/source/tlang/testing/simple_comments.t";
    string sourceEntry = gibFileData(inputFilePath);

    
    Compiler c = new Compiler(sourceEntry, inputFilePath, File("/tmp/kak.bruh", "wb"));
    c.doLex();
    c.doParse();

    Program prog = c.getProgram();
    DocumentGenerator dg = new DocumentGenerator("out/", prog);

    dg.generate();
}