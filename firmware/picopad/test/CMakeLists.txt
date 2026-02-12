cmake_minimum_required(VERSION 3.13)

project(switch_controller_tests C)

set(CMAKE_C_STANDARD 11)

set(SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../src)

add_library(protocol_lib STATIC
    ${SRC_DIR}/cobs.c
    ${SRC_DIR}/crc8.c
    ${SRC_DIR}/controller_state.c
    ${SRC_DIR}/host_protocol.c
)

target_include_directories(protocol_lib PUBLIC ${SRC_DIR})

add_executable(test_cobs test_cobs.c)
target_include_directories(test_cobs PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(test_cobs protocol_lib)

add_executable(test_crc8 test_crc8.c)
target_include_directories(test_crc8 PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(test_crc8 protocol_lib)

add_executable(test_protocol test_protocol.c)
target_include_directories(test_protocol PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(test_protocol protocol_lib)

add_executable(test_integration test_integration.c)
target_include_directories(test_integration PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(test_integration protocol_lib)

enable_testing()

add_test(NAME cobs COMMAND test_cobs)
add_test(NAME crc8 COMMAND test_crc8)
add_test(NAME protocol COMMAND test_protocol)
add_test(NAME integration COMMAND test_integration)

add_custom_target(run_all_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure
    DEPENDS test_cobs test_crc8 test_protocol test_integration
)
