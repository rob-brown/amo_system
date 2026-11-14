cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(nordicpad_dongle)

set(BTSTACK_ROOT "$ENV{HOME}/code/pico-sdk/lib/btstack" CACHE PATH "BTstack source tree")
set(NORDICPAD_DIR ${CMAKE_CURRENT_LIST_DIR}/..)
set(SOURCE_DIR ${NORDICPAD_DIR}/src)
set(GENERATED_IDENTITY ${SOURCE_DIR}/generated/identity_data.c)
set(GATT_FILE ${SOURCE_DIR}/ble/pro/nordicpad.gatt)
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
file(GLOB BTSTACK_ZEPHYR ${BTSTACK_ROOT}/chipset/zephyr/*.c)
list(FILTER BTSTACK_CORE EXCLUDE REGEX "lc3|hci_transport_")
list(REMOVE_ITEM BTSTACK_BLE ${BTSTACK_ROOT}/src/ble/le_device_db_tlv.c)

include(${NORDICPAD_DIR}/cmake/nordicpad_core_sources.cmake)
list(FILTER NORDICPAD_CORE_SOURCES EXCLUDE REGEX "file_pairing_store")

add_dependencies(app nordicpad_gatt_header)

target_sources(app PRIVATE
    ${GENERATED_IDENTITY}
    ${BTSTACK_CORE}
    ${BTSTACK_BLE}
    ${BTSTACK_ZEPHYR}
    ${BTSTACK_ROOT}/3rd-party/rijndael/rijndael.c
    ${NORDICPAD_CORE_SOURCES}
    ${BTSTACK_ROOT}/platform/embedded/hci_dump_embedded_stdout.c
    ${CMAKE_CURRENT_LIST_DIR}/src/main.c
    ${CMAKE_CURRENT_LIST_DIR}/src/reboot.c
    ${SOURCE_DIR}/app/app.c
    ${SOURCE_DIR}/app/host_service.c
    ${SOURCE_DIR}/ble/ble_diagnostics.c
    ${SOURCE_DIR}/ble/ble_link_key.c
    ${SOURCE_DIR}/ble/ble_peripheral.c
    ${SOURCE_DIR}/ble/gatt_bridge.c
    ${SOURCE_DIR}/platform/mac_ble_platform.c
    ${SOURCE_DIR}/platform/zephyr_cdc_transport.c
    ${SOURCE_DIR}/platform/zephyr_chipset.c
    ${SOURCE_DIR}/platform/zephyr_hci_transport.c
    ${SOURCE_DIR}/platform/zephyr_run_loop.c
    ${SOURCE_DIR}/storage/zephyr_flash_pairing_store.c
)

target_include_directories(app PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}
    ${GATT_OUTPUT_DIR}
    ${SOURCE_DIR}
    ${BTSTACK_ROOT}/src
    ${BTSTACK_ROOT}/chipset/zephyr
    ${BTSTACK_ROOT}/platform/embedded
    ${BTSTACK_ROOT}/3rd-party/rijndael
)

target_compile_definitions(app PRIVATE NORDICPAD_PRO_CONTROLLER)

option(NORDICPAD_DONGLE_HCI_DUMP "Print every HCI packet on the console port" OFF)
if(NORDICPAD_DONGLE_HCI_DUMP)
    target_compile_definitions(app PRIVATE NORDICPAD_DONGLE_HCI_DUMP)
endif()
