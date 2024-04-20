module tpkg.lib.project;

import std.json;
import tpkg.logging;
import std.string : format;

public struct Project
{
    private string name;
    private string description;

    public void setName(string name)
    {
        this.name = name;
    }

    public void setDescription(string description)
    {
        this.description = description;
    }

    public string getName()
    {
        return this.name;
    }

    public string getDescription()
    {
        return this.description;
    }

    public JSONValue serialize()
    {
        JSONValue root;

        root["name"] = this.name;
        root["description"] = this.description;

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