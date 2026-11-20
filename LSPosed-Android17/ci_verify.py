#!/usr/bin/env python3
"""Android 17 static package checks. Passing does not certify runtime compatibility."""
import sys,hashlib,struct,json
from zipfile import ZipFile
from pathlib import Path
ABIS=("arm64-v8a","armeabi-v7a","x86","x86_64")
NEED=["manager.apk","daemon.apk","daemon","module.prop","framework/vector.dex","service.sh","customize.sh","sepolicy.rule"]
for a in ABIS:
    NEED+=["lib/"+a+"/libzygisk.so","bin/"+a+"/dex2oat","bin/"+a+"/liboat_hook.so"]
def aligns(b):
    if b[:4]!=b"\x7fELF": raise ValueError("not ELF")
    p="<" if b[5]==1 else ">"
    if b[4]==2:
        h=struct.unpack_from(p+"16sHHIQQQIHHHHHH",b)
        fmt=p+"IIQQQQQQ"
    elif b[4]==1:
        h=struct.unpack_from(p+"16sHHIIIIIHHHHHH",b)
        fmt=p+"IIIIIIII"
    else: raise ValueError("ELF class")
    phoff,entsize,count=h[5],h[9],h[10]
    if not count or entsize<struct.calcsize(fmt): raise ValueError("program headers")
    out=[]
    for n in range(count):
        pos=phoff+n*entsize
        if pos+struct.calcsize(fmt)>len(b): raise ValueError("short ELF")
        row=struct.unpack_from(fmt,b,pos)
        if row[0]==1: out.append(row[7])
    if not out: raise ValueError("no PT_LOAD")
    return out
def run(path):
    failures=[]
    with ZipFile(path) as z:
        names=z.namelist(); entries=set(names)
        if z.testzip() is not None: failures.append("ZIP CRC")
        if len(names)!=len(entries): failures.append("duplicate paths")
        if any(n.startswith("/") or ".." in n.split("/") for n in names): failures.append("unsafe paths")
        for n in NEED:
            if n not in entries: failures.append("missing "+n)
        if "module.prop" in entries:
            prop=dict(s.split("=",1) for s in z.read("module.prop").decode().splitlines() if "=" in s)
            if prop.get("id")!="zygisk_vector": failures.append("module ID")
            if "17" not in prop.get("description",""): failures.append("Android 17 not declared")
            if prop.get("versionCode")!="3119": failures.append("version code")
            if "6f6b976e" not in prop.get("version",""): failures.append("source revision")
        for n in names:
            if not n.endswith(".sha256"): continue
            orig=n[:-7]
            if orig not in entries: failures.append("orphan checksum "+n); continue
            expected=z.read(n).decode().strip().split()[0].lower()
            if hashlib.sha256(z.read(orig)).hexdigest()!=expected:
                failures.append("sha256 "+orig)
        for n in NEED:
            if n in entries and (n.endswith(".so") or n.endswith("/dex2oat")):
                try:
                    aa=aligns(z.read(n))
                    if any(x<16384 or x&(x-1) for x in aa):
                        failures.append("16KiB ELF "+n)
                except Exception as ex: failures.append("ELF "+n+": "+str(ex))
        for n in ("manager.apk","daemon.apk"):
            if n in entries:
                from io import BytesIO
                with ZipFile(BytesIO(z.read(n))) as a:
                    if a.testzip() is not None: failures.append("APK CRC "+n)
                    if "AndroidManifest.xml" not in a.namelist(): failures.append("APK manifest "+n)
                    if not any(s.startswith("classes") and s.endswith(".dex") for s in a.namelist()): failures.append("APK DEX "+n)
    return {"zip":str(path),"sha256":hashlib.sha256(Path(path).read_bytes()).hexdigest(),
            "android17_static_preflight":"PASS" if not failures else "FAIL",
            "android17_runtime_test":"NOT_RUN",
            "full_port_status":"NOT_VERIFIED",
            "failures":failures}
if __name__=="__main__":
    path=sys.argv[1]; output=sys.argv[2]
    result=run(path); Path(output).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,indent=2))
    sys.exit(1 if result["failures"] else 0)
