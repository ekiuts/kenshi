cmake_minimum_required(VERSION 3.5)

set(MOD_NAME "Kenshi-Compact")
set(CMAKE_CXX_COMPILER "C:/Program Files (x86)/Microsoft Visual Studio 10.0/VC/bin/cl.exe")
set(CMAKE_C_COMPILER "C:/Program Files (x86)/Microsoft Visual Studio 10.0/VC/bin/cl.exe")

project(${MOD_NAME} LANGUAGES CXX)

set(PROJECT_NAME "Kenshi Compact")
set(PROJECT_VERSION "1.0.4")
set(PROJECT_DESCRIPTION "Allows access to the Character Editor during gameplay.")

# ────────────────────────────────────────────────
#  Force MSVC v100 (Visual Studio 2010 toolset)
# ────────────────────────────────────────────────
set(CMAKE_GENERATOR_TOOLSET "v100" CACHE STRING "" FORCE)

# ────────────────────────────────────────────────
#  Include directories
# ────────────────────────────────────────────────
INCLUDE_DIRECTORIES(
    "$ENV{DXSDK_DIR}"

    # KenshiLib
    "$ENV{KENSHILIB}/Include"
    "$ENV{KENSHILIB}/Include/core"
    "$ENV{KENSHILIB}/Include/kenshi"
    "$ENV{KENSHILIB}/Include/mygui"
    "$ENV{KENSHILIB}/Include/ogre"
    "$ENV{KENSHILIB}/Include/ois"

    # Boost
    "$ENV{BOOST_INCLUDE_PATH}"
    "$ENV{BOOST_INCLUDE_PATH}/stage/lib"
)

# ────────────────────────────────────────────────
#  Source files
# ────────────────────────────────────────────────
file(GLOB SRC_FILES
    "${CMAKE_SOURCE_DIR}/src/*.cpp"
    "${CMAKE_SOURCE_DIR}/src/*.h"
)

add_library(${MOD_NAME} SHARED ${SRC_FILES})

# ────────────────────────────────────────────────
#  Preprocessor definitions
# ────────────────────────────────────────────────
target_compile_definitions(${MOD_NAME} PRIVATE
    NDEBUG
    UNICODE
    _UNICODE
    _CRT_SECURE_NO_WARNINGS
    _SCL_SECURE_NO_WARNINGS
    _SECURE_SCL=0
    _ITERATOR_DEBUG_LEVEL=0
    WINVER=0x0601
    _WIN32_WINNT=0x0601
    BOOST_ALL_NO_LIB
    BOOST_ERROR_CODE_HEADER_ONLY
)

target_compile_options(${MOD_NAME} PRIVATE /wd4091)

# ────────────────────────────────────────────────
#  Library paths
# ────────────────────────────────────────────────
set(KENSHILIB_LIB "$ENV{KENSHILIB}/Libraries/KenshiLib.lib")
set(OGREMAIN_LIB  "$ENV{KENSHILIB}/Libraries/OgreMain_x64.lib")
set(MYGUI_LIB    "$ENV{KENSHILIB}/Libraries/MyGUIEngine_x64.lib")

# ────────────────────────────────────────────────
#  Link libraries
# ────────────────────────────────────────────────
target_link_libraries(${MOD_NAME} PRIVATE
    ${KENSHILIB_LIB}
    ${OGREMAIN_LIB}
    ${MYGUI_LIB}
)

# ────────────────────────────────────────────────
#  Output directories
# ────────────────────────────────────────────────
set_target_properties(${MOD_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
)
