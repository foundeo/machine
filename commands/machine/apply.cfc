/**
 * Sets up servers
 * .
 * Examples
 * {code:bash}
 * machine apply path=machine.json
 * {code}
 **/

component extends="base" {
    
    /**
    * @path.hint A json file with machine definition
    * @overwrite.hint If true overwrites configuration files
    */ 
    public function run(path="/etc/machine/machine.json", overwrite=false) {
        var machine = parseMachineFile(path);
        var site = "";
        var site_id = "";
        var mustache = getInstance("Mustache@machine");
        var template = "";
        if (!directoryExists("/etc/machine/")) {
            directoryCreate("/etc/machine/");
        }
        if (!fileExists("/etc/machine/machine.env")) {
            fileCopy(getEtcTemplatePath("machine/machine.env"), "/etc/machine/machine.env");
            fileSetAccessMode("/etc/machine/machine.env", 700);
        }
        machine = validateMachineFile(machine);
        for (site_id in machine.sites.keyArray()) {
            site = machine.sites[site_id];
            if (!userExists(site_id)) {
                //adduser --system -shell /sbin/nologin username
                print.greenLine(" + Creating user account: #site_id#");
                print.blueLine(command("run").params("adduser --system -shell /sbin/nologin #site_id#").run( returnOutput=true ));
                print.greenLine(" + User: #site_id# created.");
            } else {
                print.yellowLine(" - User: #site_id# already exists, skipping adding new user.");
            }
            deploySite(site_id, site, machine);
            //deploy service
            site = validateSite(site, machine);
            local.site_service_path = "/etc/systemd/system/#site_id#.service";
            
            if (!fileExists(site.server_json)) {
                error("server.json file does not exist in the wwwroot. Expected: #site.server_json#");
            }
            //create script file
            if (!fileExists("/etc/machine/#site_id#.sh") || arguments.overwrite) {
                template = fileRead(getEtcTemplatePath("machine/service-template.sh"));
                template = mustache.render(template, {machine=machine, site=site, environment=server.system.environment});
                fileWrite("/etc/machine/#site_id#.sh", template);
                fileSetAccessMode("/etc/machine/#site_id#.sh", 755);
                print.greenLine(" + Service: #site_id# created service script");
            } else {
                print.yellowLine(" - Service: #site_id# already has a service script file");
            }
            //create systemd service
            if (!fileExists(local.site_service_path) || arguments.overwrite) {
                template = fileRead(getEtcTemplatePath("systemd/system/template.service"));
                template = mustache.render(template, {machine=machine, site=site, environment=server.system.environment});
                
                fileWrite(local.site_service_path, template);
                fileSetAccessMode(local.site_service_path, 700);
                print.greenLine(" + Service: #site_id# created systemd service");
                print.blueLine(command("run").params("systemctl enable #site_id#.service").run( returnOutput=true ));
                print.greenLine(" + Service: #site_id# enabled systemd service");
            } else {
                print.yellowLine(" - Service: #site_id# already deployed as a systemd service");
            }

            print.greenLine(" + Service: #site_id# attempting to start service").toConsole();
            command("run").params("systemctl start #site_id#.service").run( returnOutput=true );
            if (machine.webserver.type == "nginx") {
                print.greenLine(" + Web Server: #site_id# writing nginx configuration").toConsole();
                //create nginx site
                if (!fileExists("/etc/nginx/conf.d/machine-global.conf") || arguments.overwrite) {
                    template = fileRead(getEtcTemplatePath("nginx/conf.d/machine-global.conf"));
                    template = mustache.render(template, {machine=machine, environment=server.system.environment});
                    fileWrite("/etc/nginx/conf.d/machine-global.conf", template);
                }
                if (!fileExists("/etc/nginx/machine-server.conf") || arguments.overwrite) {
                    template = fileRead(getEtcTemplatePath("nginx/machine-server.conf"));
                    template = mustache.render(template, {machine=machine, environment=server.system.environment});
                    fileWrite("/etc/nginx/machine-server.conf", template);
                }
                if (!fileExists("/etc/nginx/#site_id#-proxy.conf") || arguments.overwrite) {
                    template = fileRead(getEtcTemplatePath("nginx/template-proxy.conf"));
                    template = mustache.render(template, {machine=machine, site=site, environment=server.system.environment});
                    fileWrite("/etc/nginx/#site_id#-proxy.conf", template);
                }
                if (!fileExists("/etc/nginx/sites-available/#site_id#.conf") || arguments.overwrite) {
                    template = fileRead(getEtcTemplatePath("nginx/sites-available/site-template.conf"));
                    template = mustache.render(template, {machine=machine, site=site, environment=server.system.environment});
                    fileWrite("/etc/nginx/sites-available/#site_id#.conf", template);
                }

                //if ssl certificate does not exist generate self signed certs
                if (site.keyExists("webserver") && site.webserver.keyExists("https") && site.webserver.https)  {
                    print.greenLine(" + Web Server: #site_id# is https enabled, running checks").toConsole();
                    if (site.webserver.keyExists("ssl_certificate_key") && !fileExists(site.webserver.ssl_certificate_key)) {
                        print.yellowLine(" - Web Server: #site_id# ssl_certificate_key file does not exist, generating self signed cert: #site.webserver.ssl_certificate_key#").toConsole();
                        if (!directoryExists(getDirectoryFromPath(site.webserver.ssl_certificate_key))) {
                            directoryCreate(getDirectoryFromPath(site.webserver.ssl_certificate_key), true);
                        }
                        //assumes all certs and keys are in the same directory
                        local.output = command("run").params("openssl req -subj ""/CN=#site_id#"" -new -x509 -sha256 -newkey rsa:2048 -nodes -keyout #site.webserver.ssl_certificate_key# -days 365 -out #site.webserver.ssl_certificate#").run( returnOutput=true );
                        print.blueLine(local.output).toConsole();
                        fileWrite('/tmp/out.txt', local.output);
                        if (fileExists(site.webserver.ssl_certificate_key)) {
                            print.greenLine(" + Web Server: #site_id# self signed cert generation was successful.").toConsole();
                            if (site.webserver.keyExists("ssl_trusted_certificate")) {
                                fileCopy(site.webserver.ssl_certificate, site.webserver.ssl_trusted_certificate);
                                fileSetAccessMode(site.webserver.ssl_certificate_key, 700);
                            }
                        } else {
                            print.yellowLine(" - Web Server: #site_id# self signed cert generation was unsuccessful.").toConsole();
                        }
                        
                        
                    }
                }
                
                if (!fileExists("/etc/nginx/sites-enabled/#site_id#.conf")) {
                    print.yellowLine(" + Web Server: #site_id# enabling site on nginx.").toConsole();
                    print.blueLine(command("run").params("ln -s /etc/nginx/sites-available/#site_id#.conf /etc/nginx/sites-enabled/#site_id#.conf").run( returnOutput=true ));
                } else {
                    print.yellowLine(" - Web Server: #site_id# already enabled on nginx.").toConsole();
                }

                //restart nginx
                print.greenLine(" + Web Server: #site_id# restarting nginx").toConsole();
                print.blueLine(command("run").params("systemctl restart nginx.service").run( returnOutput=true ));
                print.greenLine(" + Web Server: #site_id# done restarting nginx").toConsole();
            } else {
                print.yellowLine(" + Web Server: #site_id# not connected to a web server").toConsole();
            }
        }
        print.greenLine(" + Machine: writing /etc/machine/machine.json");
        fileCopy(serializeJSON(machine), "/etc/machine/machine.json");

        print.greenLine(" + Machine: DONE");
        
    }

    

    private function deploySite(site_id, site, machine) {
        if (site.keyExists("deploy") && isStruct(site.deploy)) {
            if (site.deploy.keyExists("git")) {
                print.greenLine(" + Deploy: Attempting to clone git path: #site.deploy.git# to #site.path#").toConsole();
                if (directoryExists(site.path & "/.git")) {
                    print.yellowLine(" - Deploy: #site.path# already a git directory, skipping clone").toConsole();
                } else {
                    print.blueLine(command("run").params("git clone #assertSafePath(site.deploy.git)# #assertSafePath(site.path)#").run( returnOutput=true ));
                    print.greenLine(" + Deploy: #site_id# cloned.").toConsole();
                }
            }
            
        } else {
            print.yellowLine(" - Deploy: #site_id# no deployment info, skipping.").toConsole();
        }
    }

    private function assertSafePath(path) {
        return path;
    }

    private function userExists(username) {
        var userFile = "/etc/passwd";
        var line = "";
        var fileHandle = fileOpen(userFile);
        while (!fileIsEOF(fileHandle)) {
            line = fileReadLine(fileHandle);
            if (listFirst(line, ":") == username) {
                return true;
            }
        }
        return false;
    }

    private function getEtcTemplatePath(template) {
        var etc = replace(getDirectoryFromPath(getCurrentTemplatePath()), "/commands/machine/", "/etc/");
        return etc & template;
    }

}