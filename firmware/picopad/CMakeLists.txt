cmake_minimum_required(VERSION 3.13)

set(PICO_BOARD pico2_w)
set(PICO_PLATFORM rp2350)

include(pico_sdk_import.cmake)

project(switch_controller C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(switch_controller
    src/main.c
    src/bt_hid.c
    src/bonding_storage.c
    src/logging.c
    src/reconnect_manager.c
    src/switch_protocol.c
    src/controller_state.c
    src/spi_flash_data.c
    src/cobs.c
    src/crc8.c
    src/host_protocol.c
    ${PICO_SDK_PATH}/lib/btstack/src/classic/btstack_link_key_db_memory.c
)

target_include_directories(switch_controller PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/src
)

target_link_libraries(switch_controller
    pico_stdlib
    pico_cyw43_arch_none
    pico_btstack_classic
    pico_btstack_cyw43
)

target_compile_definitions(switch_controller PRIVATE
    CYW43_LWIP=0
    PICO_STDIO_USB_CONNECT_WAIT_TIMEOUT_MS=3000
)

pico_enable_stdio_usb(switch_controller 1)
pico_enable_stdio_uart(switch_controller 0)

pico_add_extra_outputs(switch_controller)
