module tpkg.lib.project;

import std.json;

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

        return root;
    }

    public static Project deserialize(JSONValue json)
    {
        Project proj;

        proj.setName(json["name"].str());
        proj.setDescription(json["description"].str());

        return proj;
    }
}

unittest
{
    Project proj;

    proj.setName("tpkg");
    proj.setDescription("The TLang package manager");

    JSONValue json = proj.serialize();

    Project projOut = proj.deserialize(json);

    assert(proj.getName() == projOut.getName());
    assert(proj.getDescription() == projOut.getDescription());
}