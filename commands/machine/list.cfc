component extends="base" {

    public function run(path="/etc/machine/machine.json") {
        var machine = parseMachineFile(fileSystemUtil.resolvePath(path));
        printDump(machine);
    }

    

}