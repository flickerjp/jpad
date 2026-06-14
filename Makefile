.PHONY: project
project:
	xcodegen generate
	./scripts/fix-xcode-spm.sh
	rm -rf ../TinyTone/Packages/TinyToneCore/.swiftpm
