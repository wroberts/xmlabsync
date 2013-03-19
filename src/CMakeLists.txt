# the name of the executable to build
set(PROCESS_NAME "xmlabsync")

cmake_minimum_required (VERSION 2.6)

project (${PROCESS_NAME})

# build a universal binary
set(CMAKE_OSX_ARCHITECTURES "i386;x86_64")

# set the version number
set (${PROCESS_NAME}_VERSION_MAJOR 1)
set (${PROCESS_NAME}_VERSION_MINOR 0)

# Configure a header file to pass some of the CMake settings to the
# source code
configure_file (
  "${PROJECT_SOURCE_DIR}/${PROCESS_NAME}config.h.in"
  "${PROJECT_BINARY_DIR}/${PROCESS_NAME}config.h"
  )

# Add the binary tree to the search path for include files so that we
# will find ${PROCESS_NAME}config.h
include_directories(google
                    "${PROJECT_BINARY_DIR}")

set(PROCESS_SRCS
  xmlabsync.m
  google/GTMStringEncoding.m
  CMakeLists.txt
  )

# build a command-line executable
add_executable(${PROCESS_NAME} ${PROCESS_SRCS})

# automatically find frameworks
find_library(FOUNDATION_FRAMEWORK Foundation)
find_library(ADDRESSBOOK_FRAMEWORK AddressBook)

# link
target_link_libraries(
  ${PROCESS_NAME}
  ${FOUNDATION_FRAMEWORK}
  ${ADDRESSBOOK_FRAMEWORK}
  )
