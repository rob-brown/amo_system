#include "test_replay.h"

#include "controller/identity.h"
#include "storage/ram_pairing_store.h"

static const uint8_t JOYCON_R_ADDRESS_LE[PAIRING_ADDRESS_SIZE] = {0x0E, 0x75, 0xDE, 0x55, 0xE2, 0x98};

static bool test_every_recorded_init_exchange_is_reproduced(void) {
    // Arrange
    ram_pairing_store_t ram_store;
    ram_pairing_store_init(&ram_store);
    pairing_t pairing;
    pairing_init(&pairing, &ram_store.store, JOYCON_R_ADDRESS_LE);
    command_set_t set;
    ASSERT(command_set_init(&set, &CONTROLLER_IDENTITY, &pairing));
    int replayed = 0;

    // Act
    bool reproduced = replay_fixture(&set, FIXTURE_DIR "/init_exchanges.txt", &replayed);

    // Assert
    ASSERT(reproduced);
    ASSERT(replayed > 0);
    return true;
}

TEST_MAIN_BEGIN("init_replay")
    RUN_TEST(test_every_recorded_init_exchange_is_reproduced);
TEST_MAIN_END()
