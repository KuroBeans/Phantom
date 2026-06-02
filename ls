// ls.src  |  remote lib scanner helper  |  build locally, upload via lscan
// runs on target, scans its own /lib, stores results in gco
gco = get_custom_object
metaxploit = include_lib("/lib/metaxploit.so")
if not metaxploit then exit("ls: metaxploit not found")

folder = get_shell.host_computer.File("/lib")
if not folder then exit("ls: /lib not found")
libs = folder.get_files
if not libs then exit("ls: no libs")

results = []
for lib in libs
    ml = metaxploit.load("/lib/" + lib.name)
    if not ml then continue
    if ml.is_patched then continue
    mems = metaxploit.scan(ml)
    if not mems then continue
    for mem in mems
        addrs = metaxploit.scan_address(ml, mem).split("Unsafe check: ")
        for addr in addrs
            if addr == addrs[0] then continue
            val = addr[addr.indexOf("<b>") + 3 : addr.indexOf("</b>")]
            results.push(ml.lib_name + " " + ml.version + " " + mem + " " + val)
        end for
    end for
end for
gco.lscanResults = results.join(char(10))
