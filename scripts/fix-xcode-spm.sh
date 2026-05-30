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
    r"\t\t([A-F0-9]+) /\* XCLocalSwiftPackageReference \"\.\./tinytone/Packages/TinyToneCore\" \*/ =",
    text,
)
if not package_ref_match:
    raise SystemExit("TinyToneCore package reference not found in project.pbxproj")
package_ref_id = package_ref_match.group(1)
package_ref = (
    f"{package_ref_id} "
    '/* XCLocalSwiftPackageReference "../tinytone/Packages/TinyToneCore" */'
)

product_block = re.compile(
    r"(\t\t[A-F0-9]+ /\* TinyToneCore \*/ = \{\n"
    r"\t\t\tisa = XCSwiftPackageProductDependency;\n)"
    r"((?:\t\t\tpackage = [^\n]+\n)?)"
    r"(\t\t\tproductName = TinyToneCore;\n\t\t\};)",
    re.MULTILINE
)

def patch_product_block(match: re.Match[str]) -> str:
    package_line = match.group(2)
    if package_ref_id in package_line:
        return match.group(0)
    return f"{match.group(1)}\t\t\tpackage = {package_ref};\n{match.group(3)}"

text, product_count = product_block.subn(patch_product_block, text, count=1)
if product_count != 1:
    raise SystemExit("TinyToneCore product dependency block not found")

# Remove stray Packages group / folder references that XcodeGen adds for the
# local package folder.
text = re.sub(
    r"\t\t[A-F0-9]+ /\* TinyToneCore \*/ = \{isa = PBXFileReference; lastKnownFileType = folder; "
    r"name = TinyToneCore; path = \.\./tinytone/Packages/TinyToneCore; sourceTree = SOURCE_ROOT; \};\n",
    "",
    text,
)
text = re.sub(
    r"\t\t[A-F0-9]+ /\* Packages \*/ = \{\n"
    r"\t\t\tisa = PBXGroup;\n"
    r"\t\t\tchildren = \(\n"
    r"(?:\t\t\t\t[A-F0-9]+ /\* TinyToneCore \*/,\n)?"
    r"\t\t\t\);\n"
    r"\t\t\tname = Packages;\n"
    r"\t\t\tsourceTree = \"<group>\";\n"
    r"\t\t\};\n",
    "",
    text,
)
text = re.sub(r"\t\t[A-F0-9]+ /\* Packages \*/,\n", "", text)

path.write_text(text)
print(f"Patched {path}")
PY
