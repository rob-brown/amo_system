cmake_minimum_required(VERSION 3.13)

set(PICO_BOARD pico2_w)
set(PICO_PLATFORM rp2350)

include(${CMAKE_CURRENT_LIST_DIR}/../pico_sdk_import.cmake)

project(nordicpad C CXX ASM)

set(CMAKE_C_STANDARD 11)

pico_sdk_init()

set(SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/src)
set(GENERATED_IDENTITY ${SOURCE_DIR}/generated/identity_data.c)

if(NOT EXISTS ${GENERATED_IDENTITY})
    message(FATAL_ERROR "Missing ${GENERATED_IDENTITY}: run scripts/extract_fixtures.exs on a capture first")
endif()

include(${CMAKE_CURRENT_LIST_DIR}/cmake/nordicpad_core.cmake)

add_executable(nordicpad
    ${GENERATED_IDENTITY}
    ${SOURCE_DIR}/app/app.c
    ${SOURCE_DIR}/app/host_service.c
    ${SOURCE_DIR}/ble/ble_diagnostics.c
    ${SOURCE_DIR}/ble/ble_link_key.c
    ${SOURCE_DIR}/ble/ble_peripheral.c
    ${SOURCE_DIR}/ble/gatt_bridge.c
    ${SOURCE_DIR}/main.c
    ${SOURCE_DIR}/platform/pico_ble_platform.c
    ${SOURCE_DIR}/storage/flash_pairing_store.c
)

target_include_directories(nordicpad PRIVATE ${SOURCE_DIR})

option(NORDICPAD_DIAGNOSTIC_DISCONNECT_MS "Drop every connection after this many ms (sniffer aid)" "")
if(NORDICPAD_DIAGNOSTIC_DISCONNECT_MS)
    target_compile_definitions(nordicpad PRIVATE NORDICPAD_DIAGNOSTIC_DISCONNECT_MS=${NORDICPAD_DIAGNOSTIC_DISCONNECT_MS})
endif()

target_link_libraries(nordicpad
    nordicpad_core
    pico_stdlib
    pico_btstack_ble
    pico_btstack_cyw43
    pico_cyw43_arch_none
)

set(NORDICPAD_CONTROLLER "joycon_r" CACHE STRING "Controller to emulate: joycon_r or pro")
if(NORDICPAD_CONTROLLER STREQUAL "pro")
    pico_btstack_make_gatt_header(nordicpad PRIVATE ${SOURCE_DIR}/ble/pro/nordicpad.gatt)
    target_compile_definitions(nordicpad PRIVATE NORDICPAD_PRO_CONTROLLER)
else()
    pico_btstack_make_gatt_header(nordicpad PRIVATE ${SOURCE_DIR}/ble/nordicpad.gatt)
endif()

pico_enable_stdio_usb(nordicpad 1)
pico_enable_stdio_uart(nordicpad 0)

pico_add_extra_outputs(nordicpad)
