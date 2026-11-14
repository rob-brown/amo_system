include(${CMAKE_CURRENT_LIST_DIR}/nordicpad_core_sources.cmake)

add_library(nordicpad_core STATIC ${NORDICPAD_CORE_SOURCES})

target_include_directories(nordicpad_core PUBLIC ${NORDICPAD_SOURCE_DIR})
