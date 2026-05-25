#!/bin/sh
# XcodeGen omits the package link on local SPM products and adds a Packages/
# folder reference that makes Xcode try to open TinyToneCore as a standalone
# package project (broken .swiftpm/xcode on network volumes).
set -eu

PBX="JPad.xcodeproj/project.pbxproj"

python3 - "$PBX" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()

package_ref_match = re.search(
    r"(\t\t[A-F0-9]+ /\* XCLocalSwiftPackageReference \"\.\./tinytone/Packages/TinyToneCore\" \*/ =)",
    text,
)
if not package_ref_match:
    raise SystemExit("TinyToneCore package reference not found in project.pbxproj")
package_ref_id = re.search(
    r"([A-F0-9]+) /\* XCLocalSwiftPackageReference",
    package_ref_match.group(1),
).group(1)
package_ref = (
    f"{package_ref_id} "
    '/* XCLocalSwiftPackageReference "../tinytone/Packages/TinyToneCore" */'
)

product_block = re.compile(
    r"(\t\t[A-F0-9]+ /\* TinyToneCore \*/ = \{\n"
    r"\t\t\tisa = XCSwiftPackageProductDependency;\n)"
    r"(\t\t\tproductName = TinyToneCore;\n"
    r"\t\t\};)",
    re.MULTILINE,
)
match = product_block.search(text)
if not match:
    raise SystemExit("TinyToneCore product dependency block not found")
product_id = re.match(r"\t\t([A-F0-9]+)", match.group(0)).group(1)
if f"package = {package_ref_id}" not in text:
    text, count = product_block.subn(
        rf"\1\t\t\tpackage = {package_ref};\n\2",
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit("Could not patch TinyToneCore product dependency")

# Remove stray Packages group / folder file references from the project navigator.
text = re.sub(
    r"\t\t[A-F0-9]+ /\* TinyToneCore \*/ = \{isa = PBXFileReference; lastKnownFileType = folder; "
    r"name = TinyToneCore; path = \.\./tinytone/Packages/TinyToneCore; sourceTree = SOURCE_ROOT; \};\n",
    "",
    text,
)
text = re.sub(r"\t\t[A-F0-9]+ /\* TinyToneCore \*/,?\n", "", text, count=1)
text = re.sub(
    r"\t\t[A-F0-9]+ /\* Packages \*/ = \{\n"
    r"\t\t\tisa = PBXGroup;\n"
    r"\t\t\tchildren = \(\n"
    r"\t\t\t\);\n"
    r"\t\t\tname = Packages;\n"
    r"\t\t\tsourceTree = \"<group>\";\n"
    r"\t\t\};\n",
    "",
    text,
)
text = re.sub(r"\t\t[A-F0-9]+ /\* Packages \*/,?\n", "", text, count=1)

path.write_text(text)
print(f"Patched {path}")
PY
