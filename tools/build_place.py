"""Build DC-Allies.rbxlx from src/ without needing Rojo installed.

Usage:  python tools/build_place.py
Then open DC-Allies.rbxlx in Roblox Studio and press Play.

File naming follows Rojo conventions:
  *.server.lua -> Script, *.client.lua -> LocalScript, *.lua -> ModuleScript, folders -> Folder
"""
import os
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "DC-Allies.rbxlx")

_ref = 0


def ref():
    global _ref
    _ref += 1
    return "RBX%d" % _ref


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, children=(), props=""):
    body = '<Item class="%s" referent="%s"><Properties><string name="Name">%s</string>%s</Properties>' % (
        cls, ref(), escape(name), props)
    return body + "".join(children) + "</Item>"


def script_item(path):
    base = os.path.basename(path)
    with open(path, encoding="utf-8") as f:
        src = f.read()
    if base.endswith(".server.lua"):
        cls, name = "Script", base[: -len(".server.lua")]
    elif base.endswith(".client.lua"):
        cls, name = "LocalScript", base[: -len(".client.lua")]
    else:
        cls, name = "ModuleScript", base[: -len(".lua")]
    return item(cls, name, props='<ProtectedString name="Source">%s</ProtectedString>' % cdata(src))


def folder_children(directory):
    out = []
    for entry in sorted(os.listdir(directory)):
        full = os.path.join(directory, entry)
        if os.path.isdir(full):
            out.append(item("Folder", entry, folder_children(full)))
        elif entry.endswith(".lua") or entry.endswith(".luau"):
            out.append(script_item(full))
    return out


def src(*parts):
    return os.path.join(ROOT, "src", *parts)


def main():
    tree = [
        item("ReplicatedStorage", "ReplicatedStorage", [item("Folder", "Shared", folder_children(src("shared")))]),
        item("ServerScriptService", "ServerScriptService", [item("Folder", "Server", folder_children(src("server")))]),
        item("StarterPlayer", "StarterPlayer", [
            item("StarterPlayerScripts", "StarterPlayerScripts", [item("Folder", "Client", folder_children(src("client")))]),
            item("StarterCharacterScripts", "StarterCharacterScripts", folder_children(src("character"))),
        ], props='<bool name="EnableMouseLockOption">false</bool>'),
    ]
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
           + "".join(tree) + "</roblox>")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(xml)
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
