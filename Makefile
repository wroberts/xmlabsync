all : build/Debug/absync

build/Debug/absync : build/absync.xcodeproj/
	cd build && xcodebuild

build/absync.xcodeproj/ : src/CMakeLists.txt
	mkdir -p build
	cd build && cmake -G Xcode ../src
