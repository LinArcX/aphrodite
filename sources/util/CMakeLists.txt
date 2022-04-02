add_library(
  util
  util.h
  util.c
)

target_link_libraries(util PUBLIC pthread)

target_include_directories(util PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}")
