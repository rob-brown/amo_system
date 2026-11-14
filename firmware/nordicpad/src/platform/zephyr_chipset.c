#include "platform/zephyr_chipset.h"

#include <string.h>

#include "btstack_chipset_zephyr.h"
#include "btstack_util.h"

#define VS_WRITE_BD_ADDR_OPCODE_LOW 0x06
#define VS_WRITE_BD_ADDR_OPCODE_HIGH 0xFC
#define BD_ADDR_SIZE 6

static btstack_chipset_t chipset;

static void write_bd_addr_command(bd_addr_t address, uint8_t *command) {
    command[0] = VS_WRITE_BD_ADDR_OPCODE_LOW;
    command[1] = VS_WRITE_BD_ADDR_OPCODE_HIGH;
    command[2] = BD_ADDR_SIZE;
    reverse_bd_addr(address, &command[3]);
}

const btstack_chipset_t *zephyr_chipset_with_public_address(void) {
    memcpy(&chipset, btstack_chipset_zephyr_instance(), sizeof(chipset));
    chipset.set_bd_addr_command = write_bd_addr_command;
    return &chipset;
}
