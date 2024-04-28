module tpkg.lib.project;

import std.json;
import tpkg.logging;
import std.string : format;

public enum ProjectType
{
    UNKNOWN,
    APPLICATION
}

public static ProjectType getProjectType(string str)
{
    if(str == "application")
    {
        return ProjectType.APPLICATION;
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

    public JSONValue serialize()
    {
        JSONValue root;

        root["name"] = this.name;
        root["description"] = this.description;
        root["dependencies"] = this.dependencies;

        DEBUG(format("Serialized to: %s ", root));

        return root;
    }

    // TODO: Must be defensively programmed
    public static bool deserialize(JSONValue json, ref Project proj)
    {
        JSONValue* nameFieldPtr = "name" in json;
        if(nameFieldPtr is null)
        {
            ERROR("Missing the 'name' field");
            return false;
        }
        else if(nameFieldPtr.type() != JSONType.string)
        {
            ERROR("The 'name' field must be a string");
            return false;
        }

        proj.setName(json["name"].str());

        JSONValue* descriptionFieldPtr = "description" in json;
        if(descriptionFieldPtr is null)
        {
            ERROR("Missing the 'description' field");
            return false;
        }
        else if(descriptionFieldPtr.type() != JSONType.string)
        {
            ERROR("The 'description' field must be a string");
            return false;
        }

        proj.setDescription(json["description"].str());

        JSONValue* projectTypePtr = "type" in json;
        if(projectTypePtr is null)
        {
            ERROR("Missing the 'type' field");
            return false;
        }
        else if(projectTypePtr.type() != JSONType.string)
        {
            ERROR("The 'type' field must be a string");
            return false;
        }

        ProjectType projectType = getProjectType(json["type"].str());
        if(projectType == ProjectType.UNKNOWN)
        {
            ERROR("The project type is not set to anything supported");
        }

        proj.setType(projectType);

        if(projectType == ProjectType.APPLICATION)
        {
            JSONValue* entrypointPtr = "entrypoint" in json;
            if(entrypointPtr is null)
            {
                ERROR("When using the application project type there must be an 'entrypoint' field");
                return false;
            }
            else if(entrypointPtr.type() != JSONType.string)
            {
                ERROR("The 'entrypoint' field must be a string");
                return false;
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
                    ERROR(format("A dependency must be a string not a '%s'", arrElem.type()));
                    return false;
                }
            }
        }

        return true;
    }
}

unittest
{
    Project proj;

    proj.setName("tpkg");
    proj.setDescription("The TLang package manager");

    JSONValue json = proj.serialize();

    Project projOut;
    assert(proj.deserialize(json, projOut));
    
    assert(proj.getName() == projOut.getName());
    assert(proj.getDescription() == projOut.getDescription());
}