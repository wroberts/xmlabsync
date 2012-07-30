================================================
 absync - Mac OS X Address Book Synchronization
================================================

Requirements
============

* Mac OS X 10.4 or later
* CMake 2.6 or later

Building
========

1. Check out the source from GitHub::
   
    git checkout git://github.com/wroberts/absync.git

2. Build

   ``absync`` uses CMake for building.  This implies a two-stage
   process for building.  In the first stage, CMake generates an XCode
   project.  In the second, XCode is used to build the binary.

   The commands for doing this are stored in the ``Makefile`` for easy
   reference.  From the command line, in the ``absync`` top-level
   directory::

       mkdir -p build
       cd build
       cmake -G Xcode ../src
       xcodebuild

   This will build the binary into the subdirectory ``build/Debug``.
   The build system as presented above keeps the source tree (in
   ``src``) and the build products (under ``build``) separate.
