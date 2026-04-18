cmake_minimum_required(VERSION 3.22.1)
project(flutter_midi_16kb VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Fetch Oboe
include(FetchContent)
FetchContent_Declare(
    oboe
    GIT_REPOSITORY https://github.com/google/oboe.git
    GIT_TAG 1.8.0
)
FetchContent_MakeAvailable(oboe)

find_library(log-lib log)
find_library(android-lib android)

add_library(flutter_midi_16kb SHARED
    midi_player.cpp
)

target_link_libraries(flutter_midi_16kb
    oboe
    ${log-lib}
    ${android-lib}
)

target_include_directories(flutter_midi_16kb PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${oboe_SOURCE_DIR}/include
)

set_target_properties(flutter_midi_16kb PROPERTIES
    LINK_FLAGS "-Wl,-z,max-page-size=0x4000"
)

target_link_options(flutter_midi_16kb PRIVATE
        -Wl,-z,max-page-size=0x4000
)
