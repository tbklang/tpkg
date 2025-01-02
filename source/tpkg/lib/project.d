module tpkg.lib.project;

import std.json;
import tpkg.logging;
import std.string : format;
import niknaks.functional : Result, ok, error;

public enum ProjectType
{
    UNKNOWN,
    APPLICATION,
    LIBRARY
}

public static ProjectType getProjectType(string str)
{
    if(str == "application")
    {
        return ProjectType.APPLICATION;
    }
    else if(str == "library")
    {
        return ProjectType.LIBRARY;
    }
    else
    {
        return ProjectType.UNKNOWN;
    }
}

public struct Project
{
    private string name;
    private string description;
    private ProjectType type;
    private string entrypoint;
    private string[] dependencies;
    
    private string[] links;
    private string output;

    public void setName(string name)
    {
        this.name = name;
    }

    public void setDescription(string description)
    {
        this.description = description;
    }

    public void setType(ProjectType type)
    {
        this.type = type;
    }

    public void setEntrypoint(string entrypoint)
    {
        this.entrypoint = entrypoint;
    }

    public void setDependencies(string[] dependencies)
    {
        this.dependencies = dependencies;
    }

    public string getName()
    {
        return this.name;
    }

    public string getDescription()
    {
        return this.description;
    }

    public ProjectType getType()
    {
        return this.type;
    }

    public string getEntrypoint()
    {
        return this.entrypoint;
    }

    public string[] getDependencies()
    {
        return this.dependencies;
    }

    public string[] getLinks()
    {
        return this.links;
    }

    public void setLinks(string[] links)
    {
        this.links = links;
    }

    public void setOutput(string output)
    {
        this.output = output;
    }

    public string getOutput()
    {
        return this.output;
    }

    public JSONValue serialize()
    {
        JSONValue root;

        import std.string : toLower;
        import std.conv : to;
        root["name"] = this.name;
        root["description"] = this.description;
        root["dependencies"] = this.dependencies;
        root["type"] = toLower(to!(string)(this.type));

        if(this.type == ProjectType.APPLICATION)
        {
            root["entrypoint"] = this.entrypoint;
        }

        

        JSONValue buildObj = JSONValue.emptyObject;

        if(this.links.length)
        {
            buildObj["link"] = this.links;
        }

        if(this.output)
        {
            buildObj["output"] = this.output;
        }

        if(buildObj != JSONValue.emptyObject)
        {
            root["build"] = buildObj;
        }

        DEBUG(format("Serialized to: %s ", root));

        return root;
    }

    public static Result!(Project, string) deserialize(JSONValue json)
    {
        Project proj;

        JSONValue* nameFieldPtr = "name" in json;
        if(nameFieldPtr is null)
        {
            return error!(string, Project)("Missing the 'name' field");
        }
        else if(nameFieldPtr.type() != JSONType.string)
        {
            return error!(string, Project)("The 'name' field must be a string");
        }

        proj.setName(json["name"].str());

        JSONValue* descriptionFieldPtr = "description" in json;
        if(descriptionFieldPtr is null)
        {
            return error!(string, Project)("Missing the 'description' field");
        }
        else if(descriptionFieldPtr.type() != JSONType.string)
        {
            return error!(string, Project)("The 'description' field must be a string");
        }

        proj.setDescription(json["description"].str());

        JSONValue* projectTypePtr = "type" in json;
        if(projectTypePtr is null)
        {
            return error!(string, Project)("Missing the 'type' field");
        }
        else if(projectTypePtr.type() != JSONType.string)
        {
            return error!(string, Project)("The 'type' field must be a string");
        }

        string projectType_s = json["type"].str();
        ProjectType projectType = getProjectType(projectType_s);
        if(projectType == ProjectType.UNKNOWN)
        {
            return error!(string, Project)(format("The project type '%s' is not set to anything supported", projectType_s));
        }

        proj.setType(projectType);

        if(projectType == ProjectType.APPLICATION)
        {
            JSONValue* entrypointPtr = "entrypoint" in json;
            if(entrypointPtr is null)
            {
                return error!(string, Project)("When using the application project type there must be an 'entrypoint' field");
            }
            else if(entrypointPtr.type() != JSONType.string)
            {
                return error!(string, Project)("The 'entrypoint' field must be a string");
            }

            proj.setEntrypoint(json["entrypoint"].str());
        }

        JSONValue* projectDepsPtr = "dependencies" in json;
        string[] deps;
        if(projectDepsPtr)
        {
            foreach(JSONValue arrElem; projectDepsPtr.array())
            {
                if(arrElem.type() == JSONType.string)
                {
                    deps ~= arrElem.str();
                }
                else
                {
                    return error!(string, Project)(format("A dependency must be a string not a '%s'", arrElem.type()));
                }
            }
        }
        proj.setDependencies(deps);

        JSONValue* buildPtr = "build" in json;
        if(buildPtr)
        {
            if(buildPtr.type() == JSONType.OBJECT)
            {
                JSONValue* linkPtr = "link" in *buildPtr;
                if(linkPtr)
                {
                    if(linkPtr.type() == JSONType.ARRAY)
                    {
                        string[] links;
                        foreach(JSONValue links_JSON; linkPtr.array())
                        {
                            links ~= links_JSON.str();
                        }
                        proj.setLinks(links);
                    }
                    else
                    {
                        return error!(string, Project)(format("A links must be a list not a '%s'", linkPtr.type()));
                    }
                }

                JSONValue* outputPtr = "output" in *buildPtr;
                if(outputPtr)
                {
                    if(outputPtr.type() == JSONType.STRING)
                    {
                        proj.setOutput(outputPtr.str());
                    }
                    else
                    {
                        return error!(string, Project)(format("The output name must be a string not a '%s'", outputPtr.type()));
                    }
                }
            }
            else
            {
                return error!(string, Project)(format("A build must be an object not a '%s'", buildPtr.type()));
            }
        }

        return ok!(Project, string)(proj);
    }   
}

unittest
{
    Project proj;

    proj.setName("tpkg");
    proj.setDescription("The TLang package manager");
    proj.setType(ProjectType.APPLICATION);
    proj.setLinks(["std1", "std2"]);

    JSONValue json = proj.serialize();

    Project projOut;
    auto res = proj.deserialize(json);
    assert(res.is_okay());
    projOut = res.ok();
    
    assert(proj.getName() == projOut.getName());
    assert(proj.getDescription() == projOut.getDescription());
    assert(proj.getType() == ProjectType.APPLICATION);
    assert(proj.getLinks() == projOut.getLinks());
}