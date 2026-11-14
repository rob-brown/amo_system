#include "test_replay.h"

#include "controller/identity.h"
#include "nfc/nfc_session.h"
#include "storage/ram_pairing_store.h"

static const uint8_t JOYCON_R_ADDRESS_LE[PAIRING_ADDRESS_SIZE] = {0x0E, 0x75, 0xDE, 0x55, 0xE2, 0x98};

static bool load_recorded_dump(amiibo_store_t *store, const char *path) {
    uint8_t dump[AMIIBO_V3_SIZE];
    FILE *file = fopen(path, "rb");
    ASSERT(file != NULL);
    size_t size = fread(dump, 1, sizeof(dump), file);
    fclose(file);
    return amiibo_store_load(store, dump, size);
}

static bool replay_recorded_scan(const char *dump_path, const char *scan_path, int expected_exchanges) {
    static amiibo_store_t amiibo;
    static nfc_session_t nfc;
    ram_pairing_store_t ram_store;
    ram_pairing_store_init(&ram_store);
    pairing_t pairing;
    pairing_init(&pairing, &ram_store.store, JOYCON_R_ADDRESS_LE);
    command_set_t set;
    ASSERT(command_set_init(&set, &CONTROLLER_IDENTITY, &pairing));
    amiibo_store_init(&amiibo);
    ASSERT(load_recorded_dump(&amiibo, dump_path));
    nfc_session_init(&nfc, &amiibo);
    ASSERT(command_set_add_nfc(&set, &nfc));
    int replayed = 0;

    bool reproduced = replay_fixture(&set, scan_path, &replayed);

    ASSERT(reproduced);
    ASSERT_EQ(replayed, expected_exchanges);
    return true;
}

static bool test_recorded_v2_scan_is_reproduced_byte_for_byte(void) {
    // Arrange, Act, Assert
    return replay_recorded_scan(FIXTURE_DIR "/nfc_v2_dump.bin", FIXTURE_DIR "/nfc_v2_scan.txt", 18);
}

#ifdef NFC_V3_FIXTURES
static bool test_recorded_v3_scan_is_reproduced_byte_for_byte(void) {
    // Arrange, Act, Assert
    return replay_recorded_scan(FIXTURE_DIR "/nfc_v3_dump.bin", FIXTURE_DIR "/nfc_v3_scan.txt", 43);
}
#endif

TEST_MAIN_BEGIN("nfc_replay")
    RUN_TEST(test_recorded_v2_scan_is_reproduced_byte_for_byte);
#ifdef NFC_V3_FIXTURES
    RUN_TEST(test_recorded_v3_scan_is_reproduced_byte_for_byte);
#endif
TEST_MAIN_END()
