# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.22.1-g37088a8-dirty)

# We name the project and the target for the ExternalProject_Add() call
# to something that will highlight to the user what we are working on if
# something goes wrong and an error message is produced.

project(oboe-populate NONE)


# Pass through things we've already detected in the main project to avoid
# paying the cost of redetecting them again in ExternalProject_Add()
set(GIT_EXECUTABLE [==[C:/Program Files/Git/cmd/git.exe]==])
set(GIT_VERSION_STRING [==[2.53.0.windows.2]==])
set_property(GLOBAL PROPERTY _CMAKE_FindGit_GIT_EXECUTABLE_VERSION
  [==[C:/Program Files/Git/cmd/git.exe;2.53.0.windows.2]==]
)


include(ExternalProject)
ExternalProject_Add(oboe-populate
                     "UPDATE_DISCONNECTED" "False" "GIT_REPOSITORY" "https://github.com/google/oboe.git" "GIT_TAG" "1.8.0"
                    SOURCE_DIR          "C:/Users/duyvi/Documents/Github/PianoMissPass/fe/third_party/flutter_midi_16kb/android/.cxx/Debug/1gz6j1b2/x86_64/_deps/oboe-src"
                    BINARY_DIR          "C:/Users/duyvi/Documents/Github/PianoMissPass/fe/third_party/flutter_midi_16kb/android/.cxx/Debug/1gz6j1b2/x86_64/_deps/oboe-build"
                    CONFIGURE_COMMAND   ""
                    BUILD_COMMAND       ""
                    INSTALL_COMMAND     ""
                    TEST_COMMAND        ""
                    USES_TERMINAL_DOWNLOAD  YES
                    USES_TERMINAL_UPDATE    YES
)


