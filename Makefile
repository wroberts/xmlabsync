all : build/Debug/xmlabsync

build/Debug/xmlabsync : build/xmlabsync.xcodeproj/
	cd build && xcodebuild

build/xmlabsync.xcodeproj/ : src/CMakeLists.txt
	mkdir -p build
	cd build && cmake -G Xcode ../src
