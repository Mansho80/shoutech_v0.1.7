cmake_minimum_required(VERSION 3.16)
project(SecEng LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

add_library(SecEng SHARED src/prot.cpp src/ciph.cpp)

target_include_directories(SecEng PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/inc)

if(MSVC)
  target_compile_options(SecEng PRIVATE /W4 /O2)
else()
  target_compile_options(SecEng PRIVATE -Wall -Wextra -O2)
endif()

set_target_properties(SecEng PROPERTIES OUTPUT_NAME "SecEng")
