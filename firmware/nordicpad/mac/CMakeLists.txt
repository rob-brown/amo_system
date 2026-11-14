cmake_minimum_required(VERSION 3.13)

project(nordicpad_mac C)

set(CMAKE_C_STANDARD 11)

set(BTSTACK_ROOT "$ENV{HOME}/code/pico-sdk/lib/btstack" CACHE PATH "BTstack source tree")
set(NORDICPAD_DIR ${CMAKE_CURRENT_LIST_DIR}/..)
set(SOURCE_DIR ${NORDICPAD_DIR}/src)
set(GENERATED_IDENTITY ${SOURCE_DIR}/generated/identity_data.c)
set(NORDICPAD_CONTROLLER "joycon_r" CACHE STRING "Controller to emulate: joycon_r or pro")
if(NORDICPAD_CONTROLLER STREQUAL "pro")
    set(GATT_FILE ${SOURCE_DIR}/ble/pro/nordicpad.gatt)
else()
    set(GATT_FILE ${SOURCE_DIR}/ble/nordicpad.gatt)
endif()
set(GATT_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)

if(NOT EXISTS ${GENERATED_IDENTITY})
    message(FATAL_ERROR "Missing ${GENERATED_IDENTITY}: run scripts/extract_fixtures.exs on a capture first")
endif()

find_package(Python3 REQUIRED COMPONENTS Interpreter)

file(MAKE_DIRECTORY ${GATT_OUTPUT_DIR})
add_custom_command(
    OUTPUT ${GATT_OUTPUT_DIR}/nordicpad.h
    DEPENDS ${GATT_FILE}
    COMMAND ${Python3_EXECUTABLE} ${BTSTACK_ROOT}/tool/compile_gatt.py ${GATT_FILE} ${GATT_OUTPUT_DIR}/nordicpad.h
)
add_custom_target(nordicpad_gatt_header DEPENDS ${GATT_OUTPUT_DIR}/nordicpad.h)

file(GLOB BTSTACK_CORE ${BTSTACK_ROOT}/src/*.c)
file(GLOB BTSTACK_BLE ${BTSTACK_ROOT}/src/ble/*.c)
set(BTSTACK_POSIX
    ${BTSTACK_ROOT}/platform/posix/btstack_run_loop_posix.c
    ${BTSTACK_ROOT}/platform/posix/btstack_signal.c
    ${BTSTACK_ROOT}/platform/posix/btstack_uart_posix.c
    ${BTSTACK_ROOT}/platform/posix/hci_dump_posix_fs.c
    ${BTSTACK_ROOT}/platform/posix/hci_dump_posix_stdout.c
)
file(GLOB BTSTACK_ZEPHYR ${BTSTACK_ROOT}/chipset/zephyr/*.c)
list(REMOVE_ITEM BTSTACK_BLE ${BTSTACK_ROOT}/src/ble/le_device_db_tlv.c)
list(FILTER BTSTACK_CORE EXCLUDE REGEX "lc3")

include(${NORDICPAD_DIR}/cmake/nordicpad_core.cmake)

add_executable(nordicpad_mac
    ${GENERATED_IDENTITY}
    ${BTSTACK_CORE}
    ${BTSTACK_BLE}
    ${BTSTACK_POSIX}
    ${BTSTACK_ZEPHYR}
    ${BTSTACK_ROOT}/3rd-party/rijndael/rijndael.c
    ${CMAKE_CURRENT_LIST_DIR}/main.c
    ${SOURCE_DIR}/app/app.c
    ${SOURCE_DIR}/app/host_service.c
    ${SOURCE_DIR}/ble/ble_diagnostics.c
    ${SOURCE_DIR}/ble/ble_link_key.c
    ${SOURCE_DIR}/ble/ble_peripheral.c
    ${SOURCE_DIR}/ble/gatt_bridge.c
    ${SOURCE_DIR}/platform/mac_ble_platform.c
    ${SOURCE_DIR}/platform/mac_pty_transport.c
    ${SOURCE_DIR}/platform/zephyr_chipset.c
)

add_dependencies(nordicpad_mac nordicpad_gatt_header)

target_include_directories(nordicpad_mac PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}
    ${GATT_OUTPUT_DIR}
    ${SOURCE_DIR}
    ${BTSTACK_ROOT}/src
    ${BTSTACK_ROOT}/chipset/zephyr
    ${BTSTACK_ROOT}/platform/embedded
    ${BTSTACK_ROOT}/platform/posix
    ${BTSTACK_ROOT}/3rd-party/rijndael
)

target_compile_definitions(nordicpad_mac PRIVATE ENABLE_SOFTWARE_AES128)

if(NORDICPAD_CONTROLLER STREQUAL "pro")
    target_compile_definitions(nordicpad_mac PRIVATE NORDICPAD_PRO_CONTROLLER)
endif()

target_link_libraries(nordicpad_mac nordicpad_core)
