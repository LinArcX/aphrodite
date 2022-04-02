add_library(
  termbox
  termbox.h
  termbox.c
  utf8.c
)

target_link_libraries(termbox PUBLIC pthread)

target_include_directories(termbox PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}")
