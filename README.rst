================================================
 absync - Mac OS X Address Book Synchronization
================================================

Copyright (c) 2012 Will Roberts <wildwilhelm@gmail.com>.

Licensed under the MIT License (see source file ``absync.m`` for
details).

Synchronizes the Mac OS X Address Book to and from an XML-based
format.

This program is intended to help with synchronizing the system Address
Book between computers, and with tracking changes to the Address Book
by storing its contents in a version control system (I use Git_).

The process would look roughly like this::

    # export the system Address Book to XML
    absync -w abook.xml
    git commit -m "Autocommit Address Book" abook.xml
    git fetch
    # merge local abook.xml with remote abook.xml
    git merge origin/upsteam
    git push
    # integrate updated information from the XML to the system Address Book
    absync -r abook.xml

This should work for Mac OS X 10.4 and better.

.. _Git: http://git-scm.com/

Syntax
======

::

    absync Version 1.0
    Mac OS X Adddress Book Synchronization
    Copyright (c) 2012 Will Roberts

    This is a utility to export the Mac OS X Adddress Book as an XML file,
    or to read an XML file in, modifying the Address Book.

    Syntax:

       absync -w OUTFILE.XML
       absync [--no-update] [--no-delete] -r INFILE.XML
       absync --replace INFILE.XML
       absync --delete

    absync -w dumps the Address Book to the named file (or standard output
    if filename is "-").

    absync -r reads an XML file (or standard input if filename is "-"),
    creating, modifying, and deleting entries in the Address Book to
    mirror the data read.  If --no-update is specified, the tool will not
    modify any existing entries.  If --no-delete is specified, the tool
    will not delete any existing entries.

    absync --replace deletes the local address book and replaces its
    contents with the entries loaded from the given XML file.  USE WITH
    CAUTION.

    absync --delete deletes the local address book.  USE WITH CAUTION.

Known Issues
============

* Does not currently import/export image data for person records.
* No localization.
* absync could try harder to preserve UUID information when
  ``replace``-ing the Address Book.  My thinking is that the average
  user won't ``replace`` their Address Book all that often, so this is
  OK.
* ``absync --replace`` with big address books makes AddressBookSync
  unhappy, and it can sometimes take a few tries to get the Address
  Book to import completely.

Requirements
============

* Mac OS X 10.4 or later.
* CMake 2.6 or later.

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
