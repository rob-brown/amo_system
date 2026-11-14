#include "app/app.h"

#include "app/host_service.h"
#include "ble/ble_peripheral.h"
#include "btstack.h"
#include "controller/identity.h"
#include "controller/input_report.h"
#include "controller/profile.h"
#include "controller/profile_identity.h"
#include "nfc/nfc_session.h"
#include "platform/log.h"
#include "protocol/command_session.h"
#include "protocol/command_set.h"
#include "protocol/pairing.h"

#define REPLY_CAPACITY 512
#define UNKNOWN_DUMP_BYTES 160
#define NFC_COMMAND 0x01
#define NFC_POLL_SUBCOMMAND 0x05
#define NFC_LOG_SKIP 17
#define HEARTBEAT_MS 5000
#define DEFAULT_REPORT_INTERVAL_MS 15
#define CONNECTION_UNIT_NUMERATOR 5
#define CONNECTION_UNIT_DENOMINATOR 4

#ifdef NORDICPAD_PRO_CONTROLLER
#define ACTIVE_PROFILE PRO_CONTROLLER_PROFILE
#else
#define ACTIVE_PROFILE JOYCON_R_PROFILE
#endif

typedef struct {
    const controller_profile_t *profile;
    profile_identity_t identity;
    const pairing_store_t *pairing_store;
    pairing_t pairing;
    command_set_t command_set;
    command_session_t session;
    nfc_session_t nfc;
    bool ready;
    bool connected;
} app_t;

static app_t app;
static host_service_t host;
static btstack_timer_source_t heartbeat;
static btstack_timer_source_t input_timer;
static uint32_t report_interval_ms = DEFAULT_REPORT_INTERVAL_MS;

static uint32_t connection_interval_ms(uint16_t interval_units) {
    uint32_t milliseconds = (uint32_t)interval_units * CONNECTION_UNIT_NUMERATOR / CONNECTION_UNIT_DENOMINATOR;
    return milliseconds > 0 ? milliseconds : 1;
}

static host_connection_state_t connection_state(void *context) {
    UNUSED(context);

    if (app.connected) {
        return gatt_bridge_input_enabled() ? HOST_CONNECTION_READY : HOST_CONNECTION_PAIRING;
    }
    return app.ready ? HOST_CONNECTION_ADVERTISING : HOST_CONNECTION_DISCONNECTED;
}

static void input_timer_handler(btstack_timer_source_t *timer) {
    controller_input_tick(&host.input, (uint16_t)report_interval_ms);
    nfc_session_tick(&app.nfc, report_interval_ms);
    controller_input_set_nfc_counter(&host.input, nfc_session_event_counter(&app.nfc));
    host_service_publish_connection(&host, connection_state(NULL));

    if (gatt_bridge_input_enabled()) {
        uint8_t report[INPUT_REPORT_SIZE];
        controller_input_build_report(&host.input, report);
        gatt_bridge_send_input_report(report, sizeof(report));
    }
    btstack_run_loop_set_timer(timer, report_interval_ms);
    btstack_run_loop_add_timer(timer);
}

static void start_input_timer(void) {
    input_timer.process = input_timer_handler;
    btstack_run_loop_set_timer(&input_timer, report_interval_ms);
    btstack_run_loop_add_timer(&input_timer);
}

static void heartbeat_handler(btstack_timer_source_t *timer) {
    LOG("alive, ready=%d", app.ready);
    btstack_run_loop_set_timer(timer, HEARTBEAT_MS);
    btstack_run_loop_add_timer(timer);
}

static void start_heartbeat(void) {
    heartbeat.process = heartbeat_handler;
    btstack_run_loop_set_timer(&heartbeat, HEARTBEAT_MS);
    btstack_run_loop_add_timer(&heartbeat);
}

static void log_hex(const char *label, const uint8_t *bytes, size_t length) {
    printf("%s", label);
    for (size_t index = 0; index < length && index < UNKNOWN_DUMP_BYTES; index++) {
        printf(" %02x", bytes[index]);
    }
    printf("\n");
}

static void log_outcome(const command_outcome_t *outcome, const uint8_t *value, size_t length) {
    switch (outcome->status) {
    case COMMAND_OUTCOME_REPLIED:
        LOG("command %02x.%02x answered", outcome->command, outcome->subcommand);
        if (outcome->command == NFC_COMMAND && outcome->subcommand != NFC_POLL_SUBCOMMAND && length > NFC_LOG_SKIP) {
            log_hex("  nfc:", &value[NFC_LOG_SKIP], length - NFC_LOG_SKIP);
        }
        if (outcome->command != NFC_COMMAND && length > NFC_LOG_SKIP) {
            log_hex("  req:", &value[NFC_LOG_SKIP], length - NFC_LOG_SKIP);
        }
        break;
    case COMMAND_OUTCOME_UNKNOWN:
        LOG("command %02x.%02x is not implemented", outcome->command, outcome->subcommand);
        log_hex("  write:", value, length);
        break;
    case COMMAND_OUTCOME_MALFORMED:
        LOG("malformed command write");
        log_hex("  write:", value, length);
        break;
    case COMMAND_OUTCOME_REPLY_TOO_LARGE:
        LOG("reply to %02x.%02x does not fit", outcome->command, outcome->subcommand);
        break;
    }
}

static void on_command_write(void *context, const uint8_t *value, size_t length) {
    UNUSED(context);
    uint8_t reply[REPLY_CAPACITY];
    command_outcome_t outcome;

    if (!app.ready) {
        LOG("command write before the stack was ready");
        return;
    }

    size_t reply_length = command_session_handle(&app.session, value, length, reply, sizeof(reply), &outcome);
    log_outcome(&outcome, value, length);
    if (reply_length > 0) {
        gatt_bridge_send_reply(reply, reply_length);
    }
}

static void on_ready(void *context, const uint8_t local_address_le[BLE_ADDRESS_SIZE]) {
    UNUSED(context);

    pairing_init(&app.pairing, app.pairing_store, local_address_le);
    command_set_init(&app.command_set, &app.identity.identity, &app.pairing);
    command_set_add_nfc(&app.command_set, &app.nfc);
    command_session_init(&app.session, &app.command_set, app.profile->command_prefix_size);
    app.ready = true;

    uint8_t link_key[PAIRING_KEY_SIZE];
    LOG("stored link key: %s", pairing_get_link_key(&app.pairing, link_key) ? "yes" : "no");
}

static void on_set_colors(void *context, const controller_colors_t *colors) {
    UNUSED(context);

    profile_identity_set_colors(&app.identity, colors);
    LOG("controller colors changed; the console reads them when it reconnects");
}

static void on_connected(void *context) {
    UNUSED(context);
    app.connected = true;
}

static void on_disconnected(void *context) {
    UNUSED(context);
    app.connected = false;
}

static void on_interval_changed(void *context, uint16_t interval_units) {
    UNUSED(context);
    report_interval_ms = connection_interval_ms(interval_units);
    LOG("input reports every %u ms", (unsigned)report_interval_ms);
}

static bool provide_link_key(void *context, uint8_t link_key[BLE_LINK_KEY_SIZE]) {
    UNUSED(context);

    return pairing_get_link_key(&app.pairing, link_key);
}

static bool provide_host_address(void *context, uint8_t address_le[BLE_ADDRESS_SIZE]) {
    UNUSED(context);

    return app.ready && pairing_get_host_address(&app.pairing, address_le);
}

int app_run(const app_platform_t *platform) {
    app.profile = &ACTIVE_PROFILE;
    app.pairing_store = platform->pairing_store;
    LOG("nordicpad starting as %s", app.profile->name);
    if (!profile_identity_build(&app.identity, &CONTROLLER_IDENTITY, app.profile)) {
        LOG("could not build the controller identity");
        return -1;
    }

    const ble_peripheral_config_t config = {
        .profile = app.profile,
        .platform = platform->ble,
        .listener = {on_ready, on_connected, on_disconnected, on_interval_changed, NULL},
        .link_keys = {provide_link_key, NULL},
        .host_address = {provide_host_address, NULL},
        .gatt = {on_command_write, NULL},
    };

    if (ble_peripheral_start(&config) != 0) {
        return -1;
    }

    host_service_init(&host, &platform->host, connection_state, NULL);
    controller_input_set_layout(&host.input, app.profile->input_layout);
    const host_appearance_t appearance = {on_set_colors, NULL};
    host_commands_set_appearance(&host.commands, &appearance);
    host_commands_set_system(&host.commands, &platform->system);
    host_commands_set_controller_type(&host.commands, app.profile->type);
    nfc_session_init(&app.nfc, &host.amiibo);
    host_service_start(&host);
    start_heartbeat();
    start_input_timer();
    btstack_run_loop_execute();
    return 0;
}
