add_executable(${NAME} main.c)

add_subdirectory(termbox)
add_subdirectory(util)
add_subdirectory(config)

target_link_libraries(${NAME} PUBLIC termbox)
target_link_libraries(${NAME} PUBLIC util)
target_link_libraries(${NAME} PUBLIC config)
