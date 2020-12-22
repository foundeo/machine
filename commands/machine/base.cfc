component {

    public function parseMachineFile(path) {
        var jsonPath = fileSystemUtil.resolvePath( arguments.path );
        var json = "";
        var site = "";
        var site_id = "";
        if (!fileExists(jsonPath)) {
            error("Machine file does not exist on the file system: #jsonPath# ");
        }
        json = fileRead( jsonPath );
        if (!isJSON(json)) {
            error("Machine file was not valid JSON: #jsonPath# ");
        }
        json = deserializeJSON(json);

        if (!json.keyExists("webserver")) {
            json["webserver"] = {"type"="nginx"};
        }

        if (!json.keyExists("stage")) {
            json["stage"] = "production";
        }

        if (!json.keyExists("sites")) {
            json["sites"] = {};
        }

        for (site_id in json.sites.keyArray()) {
            site = json.sites[site_id];
            if (site.keyExists("path")) {
                if (!site.keyExists("wwwroot")) {
                    site["wwwroot"] = fileSystemUtil.resolvePath( site.path );
                } else if (left(site.wwwroot, 1) != "/") {
                    site["wwwroot"] = fileSystemUtil.resolvePath( site.path ) & site["wwwroot"];
                }
                if (!site.keyExists("server_json")) {
                    site["server_json"] = fileSystemUtil.resolvePath( site.wwwroot ) & "server.json";
                } else if (left(site.server_json, 1) != "/") {
                    site["server_json"] = fileSystemUtil.resolvePath( site.wwwroot ) & site["server_json"];
                }
            }
        }
        return json;
    }

    private function validateMachineFile(json) {
        var site = "";
        var site_id = "";
        var has_git = false;
        if (!json.keyExists("sites")) {
            error("Machine file was missing sites key: #jsonPath# ");
        } else if (!isStruct(json.sites)) {
            error("Machine file invalid, sites was not a struct: #jsonPath# ");
        }
        if (!json.keyExists("webserver")) {
            json["webserver"] = {"type"="nginx"};
        } else if (!isStruct(json.webserver)) {
            error("Machine file invalid, webserver was not a struct: #jsonPath# ");
        }
        if (json.webserver.type == "nginx") {
            if (!directoryExists("/etc/nginx")) {
                error("nginx does not appear to be installed, please run: apt install nginx")
            } else if (!directoryExists("/etc/nginx/sites-available/")) {
                error("nginx does not have a /etc/nginx/sites-available/ folder, not sure how to proceed.");
            }

            if (!fileExists("/etc/nginx/dhparam")) {
                cfhttp(url="https://ssl-config.mozilla.org/ffdhe2048.txt", result="local.httpResult");
                if (local.httpResult.status_code == "200") {
                    fileWrite("/etc/nginx/dhparam", local.httpResult.fileContent);
                } else {
                    printDump(local.httpResult);
                    error("Failed to download dhparams from Mozilla.");
                }
            }

        }
        for (site_id in json.sites.keyArray()) {
            site = json.sites[site_id];
            if (reFind("[^a-zA-Z0-9_]", site_id)) {
                error("Site key must be a simple string. Only alphanumeric and underscores allowed: #site_id#")
            }
            site["site_id"] = site_id;
            if (!site.keyExists("path")) {
                error("Sites must have a path key.");
            } else {
                try {
                    if (!directoryExists(site.path)) {
                        directoryCreate(site.path);
                    }
                } catch (any e) {
                    json.errors.append("Error creating site path: #site.path# - #e.message#");
                }
            }
            if (site.keyExists("deploy") && site.deploy.keyExists("git")) {
                if (!has_git) {
                    print.greenLine(" + Validation: Checking git version");
                    print.blueLine(command("run").params("git version").run( returnOutput=true )).toConsole();
                    has_git = true;
                }
                
            }
            
            
        }
        
        return json;
    }

    private function validateSite(site, machine) {
        if (!fileExists(site.server_json)) {
            error("Missing server.json file for #site.site_id#, not found: #site.server_json#");
        }
        local.server_json_data = fileRead(site.server_json);
        if (!isJSON(local.server_json_data)) {
            error("Invalid JSON file for #site.site_id#: #site.server_json#");
        }
        site["server"] = deserializeJSON(local.server_json_data);
        
        if (site.server.keyExists("web") && site.server.web.keyExists("http") && site.server.web.http.keyExists("port")) {
            site["server_port"] = site.server.web.http.port;
        }
        
        if (!site.keyExists("server_port")) {
            printDump(site);
            error("Server port not defined for #site.site_id#: #site.server_json# ");
        }

        if (site.keyExists("webserver") && site.webserver.keyExists("include")) {
            if (left(site.webserver.include, 1) != "") {
                site.webserver.include = site.path & site.webserver.include;
            }
        }

        return site;
    }




    public function printDump(any object, maxDepth=3, depth=0, label="", indent=0) {
        var pad = "";
        var type = getTypeOf(object);
        var key = "";
        if (indent != 0) {
            pad = repeatString(" ", indent*2);
        }
        //print.greenLine(repeatString("=", 50+len(pad)));
        //label = label & " (" & type & ")";
        //print.greenLine(label);
        //print.greenLine(pad & repeatString("=", 50+len(pad)));
        if (type == "struct") {
            for (key in object) {
                switch(getTypeOf(object[key])) {
                    case "string":
                    case "numeric":
                        printDumpKeyValue(key, object[key], indent);
                        break;
                    case "struct":
                        printDumpKeyValue(key, "{}", indent);
                        printDump(object=object[key], label=key, indent=indent+1, depth=depth+1, maxDepth=maxDepth);
                        
                        break;
                }
                
            }
        }
    }

    public function printDumpKeyValue(key, value, indent=0) {
        var pad = "";
        var line = "";
        if (indent != 0) {
            pad = repeatString(" ", indent*2);
        }
        key = left(key, 10);
        key = key & repeatString(" ", 10-len(key));
        value = reReplace(value, "[\n]", "\n", "ALL");
        value = reReplace(value, "[\r]", "\r", "ALL");
        if (len(value) > 30) {
            value = left(value, 30) & "...";
        }
        line = pad & key & " : " & value;
        switch(indent) {
            case 0:
                print.yellowLine(line);
                break;
            case 1: 
                print.greenLine(line);
                break;
            case 2: 
                print.blueLine(line);
                break;
            default:
                print.redLine(line);
                break;
        }
        
    }

    public function getTypeOf(any object) {
        if (isSimpleValue(object)) {
            if (isNumeric(object)) {
                return "numeric";
            } else {
                return "string";
            }
        } else {
            if (isStruct(object)) {
                return "struct";
            } else if (isArray(object)) {
                return "array";
            } else {
                return "object";
            }
        }
    }

}