add_library(
  config
  config.h
  config.c
)

target_link_libraries(config PUBLIC pthread termbox util)

target_include_directories(config PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}"
  termbox util)
