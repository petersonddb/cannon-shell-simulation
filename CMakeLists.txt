cmake_minimum_required(VERSION 3.14)
project(CannonShell)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(nlohmann_json REQUIRED)

add_executable(shell main.cpp)
target_link_libraries(shell PRIVATE nlohmann_json::nlohmann_json)
