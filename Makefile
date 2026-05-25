.PHONY: project
project:
	xcodegen generate
	./scripts/fix-xcode-spm.sh
	rm -rf ../tinytone/Packages/TinyToneCore/.swiftpm
