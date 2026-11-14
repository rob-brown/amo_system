#include "ble/ble_peripheral.h"

#include <string.h>

#include "ble/ble_diagnostics.h"
#include "ble/gatt_bridge.h"
#include "ble/gatt_handles.h"
#include "btstack.h"
#include "nordicpad.h"
#include "platform/log.h"

_Static_assert(HANDLE_INPUT_REPORT == GATT_ATTRIBUTE(GATT_INPUT_REPORT_UUID, VALUE_HANDLE),
               "input report handle must match the GATT database");
_Static_assert(HANDLE_INPUT_REPORT_CCC == GATT_ATTRIBUTE(GATT_INPUT_REPORT_UUID, CLIENT_CONFIGURATION_HANDLE),
               "input report CCC handle must match the GATT database");
_Static_assert(HANDLE_COMMAND_WRITE == GATT_ATTRIBUTE(GATT_COMMAND_WRITE_UUID, VALUE_HANDLE),
               "command write handle must match the GATT database");
_Static_assert(HANDLE_COMMAND_REPLY == GATT_ATTRIBUTE(GATT_COMMAND_REPLY_UUID, VALUE_HANDLE),
               "command reply handle must match the GATT database");
_Static_assert(HANDLE_COMMAND_REPLY_CCC == GATT_ATTRIBUTE(GATT_COMMAND_REPLY_UUID, CLIENT_CONFIGURATION_HANDLE),
               "command reply CCC handle must match the GATT database");

#define ADVERTISING_INTERVAL_UNITS 160
#define ADVERTISING_TYPE_CONNECTABLE_UNDIRECTED 0
#define ADVERTISING_CHANNEL_MAP_ALL 0x07
#define ADVERTISING_FILTER_NONE 0x00
#define DATA_LENGTH_MAX_OCTETS 251
#define DATA_LENGTH_MAX_TIME_US 2120

static ble_peripheral_config_t config;
static btstack_packet_callback_registration_t hci_registration;
static bool advertising;
static bool advertising_wanted = true;
static bool connected;
static hci_con_handle_t connection_handle;

static void address_to_le(const bd_addr_t address, uint8_t address_le[BLE_ADDRESS_SIZE]) {
    for (int index = 0; index < BLE_ADDRESS_SIZE; index++) {
        address_le[index] = address[BLE_ADDRESS_SIZE - 1 - index];
    }
}

static bool fill_host_address(uint8_t data[ADVERTISING_DATA_MAX_SIZE]) {
    uint8_t host_address_le[BLE_ADDRESS_SIZE];
    if (config.host_address.provide == NULL || !config.host_address.provide(config.host_address.context, host_address_le)) {
        return false;
    }

    memcpy(&data[config.profile->advertising_host_address_offset], host_address_le, BLE_ADDRESS_SIZE);
    return true;
}

static void begin_advertising(void) {
    bd_addr_t no_peer = {0};

    gap_advertisements_enable(0);
    gap_advertisements_set_params(ADVERTISING_INTERVAL_UNITS,
                                  ADVERTISING_INTERVAL_UNITS,
                                  ADVERTISING_TYPE_CONNECTABLE_UNDIRECTED,
                                  0,
                                  no_peer,
                                  ADVERTISING_CHANNEL_MAP_ALL,
                                  ADVERTISING_FILTER_NONE);
    static uint8_t data[ADVERTISING_DATA_MAX_SIZE];
    memcpy(data, config.profile->advertising_data, sizeof(data));
    bool reconnecting = fill_host_address(data);
    gap_advertisements_set_data((uint8_t)config.profile->advertising_data_length, data);
    if (config.profile->scan_response_length > 0) {
        static uint8_t scan_response[ADVERTISING_DATA_MAX_SIZE];
        memcpy(scan_response, config.profile->scan_response_data, sizeof(scan_response));
        gap_scan_response_set_data((uint8_t)config.profile->scan_response_length, scan_response);
    }
    gap_advertisements_enable(1);
    advertising = true;
    LOG("advertising as %s (%s)", config.profile->name, reconnecting ? "for the paired console" : "open to any console");
}

void ble_peripheral_start_advertising(void) {
    advertising_wanted = true;
    if (!connected) {
        begin_advertising();
    }
}

void ble_peripheral_stop_advertising(void) {
    advertising_wanted = false;
    gap_advertisements_enable(0);
    advertising = false;
    LOG("advertising stopped");
}

bool ble_peripheral_is_advertising(void) {
    return advertising;
}

void ble_peripheral_disconnect(void) {
    if (connected) {
        gap_disconnect(connection_handle);
    }
}

static void handle_ready(void) {
    bd_addr_t local_address;
    uint8_t local_address_le[BLE_ADDRESS_SIZE];

    config.platform.select_address(config.profile, local_address);
    address_to_le(local_address, local_address_le);
    LOG("BTstack ready, address %s", bd_addr_to_str(local_address));

    config.listener.on_ready(config.listener.context, local_address_le);
    ble_diagnostics_on_ready();
    ble_peripheral_start_advertising();
}

#ifdef NORDICPAD_DIAGNOSTIC_DISCONNECT_MS
static btstack_timer_source_t diagnostic_timer;
static hci_con_handle_t diagnostic_connection;

static void diagnostic_disconnect(btstack_timer_source_t *timer) {
    UNUSED(timer);
    LOG("diagnostic disconnect");
    gap_disconnect(diagnostic_connection);
}

static void schedule_diagnostic_disconnect(hci_con_handle_t connection) {
    diagnostic_connection = connection;
    diagnostic_timer.process = diagnostic_disconnect;
    btstack_run_loop_set_timer(&diagnostic_timer, NORDICPAD_DIAGNOSTIC_DISCONNECT_MS);
    btstack_run_loop_add_timer(&diagnostic_timer);
}
#else
static void schedule_diagnostic_disconnect(hci_con_handle_t connection) {
    UNUSED(connection);
}
#endif

static void skip_identity_lookup(hci_con_handle_t connection) {
    hci_connection_t *hci_connection = hci_connection_for_handle(connection);
    if (hci_connection != NULL) {
        hci_connection->sm_connection.sm_irk_lookup_state = IRK_LOOKUP_FAILED;
    }
}

static void handle_le_meta_event(uint8_t *packet) {
    switch (hci_event_le_meta_get_subevent_code(packet)) {
    case HCI_SUBEVENT_LE_CONNECTION_COMPLETE: {
        bd_addr_t peer;
        hci_subevent_le_connection_complete_get_peer_address(packet, peer);
        LOG("connected to %s (type %u), handle 0x%04x, interval %u",
            bd_addr_to_str(peer),
            hci_subevent_le_connection_complete_get_peer_address_type(packet),
            hci_subevent_le_connection_complete_get_connection_handle(packet),
            hci_subevent_le_connection_complete_get_conn_interval(packet));
        connected = true;
        advertising = false;
        connection_handle = hci_subevent_le_connection_complete_get_connection_handle(packet);
        skip_identity_lookup(hci_subevent_le_connection_complete_get_connection_handle(packet));
        gatt_bridge_connected(hci_subevent_le_connection_complete_get_connection_handle(packet));
        config.listener.on_connected(config.listener.context);
        config.listener.on_interval_changed(config.listener.context,
                                            hci_subevent_le_connection_complete_get_conn_interval(packet));
        hci_send_cmd(&hci_le_set_data_length,
                     hci_subevent_le_connection_complete_get_connection_handle(packet),
                     DATA_LENGTH_MAX_OCTETS,
                     DATA_LENGTH_MAX_TIME_US);
        hci_send_cmd(&hci_le_set_phy, hci_subevent_le_connection_complete_get_connection_handle(packet), 0, 2, 2, 0);
        schedule_diagnostic_disconnect(hci_subevent_le_connection_complete_get_connection_handle(packet));
        ble_diagnostics_on_connected(hci_subevent_le_connection_complete_get_connection_handle(packet));
        break;
    }
    case HCI_SUBEVENT_LE_LONG_TERM_KEY_REQUEST:
        ble_link_key_answer_request(packet, &config.link_keys);
        break;
    case HCI_SUBEVENT_LE_CONNECTION_UPDATE_COMPLETE:
        LOG("connection update: status 0x%02x, interval %u, latency %u, timeout %u",
            hci_subevent_le_connection_update_complete_get_status(packet),
            hci_subevent_le_connection_update_complete_get_conn_interval(packet),
            hci_subevent_le_connection_update_complete_get_conn_latency(packet),
            hci_subevent_le_connection_update_complete_get_supervision_timeout(packet));
        if (hci_subevent_le_connection_update_complete_get_status(packet) == ERROR_CODE_SUCCESS) {
            config.listener.on_interval_changed(config.listener.context,
                                                hci_subevent_le_connection_update_complete_get_conn_interval(packet));
        }
        break;
    default:
        LOG("le meta event 0x%02x", hci_event_le_meta_get_subevent_code(packet));
        break;
    }
}

static bool is_noisy_event(uint8_t event_type) {
    return event_type == HCI_EVENT_COMMAND_COMPLETE || event_type == HCI_EVENT_COMMAND_STATUS ||
           event_type == HCI_EVENT_NUMBER_OF_COMPLETED_PACKETS || event_type == HCI_EVENT_TRANSPORT_PACKET_SENT ||
           event_type == HCI_EVENT_VENDOR_SPECIFIC || event_type == GAP_EVENT_RSSI_MEASUREMENT;
}

static void handle_hci_event(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size) {
    UNUSED(channel);

    if (packet_type != HCI_EVENT_PACKET) {
        return;
    }

    ble_diagnostics_on_hci_event(packet);

    switch (hci_event_packet_get_type(packet)) {
    case BTSTACK_EVENT_STATE:
        if (btstack_event_state_get_state(packet) == HCI_STATE_WORKING) {
            handle_ready();
        }
        break;
    case HCI_EVENT_LE_META:
        handle_le_meta_event(packet);
        break;
    case HCI_EVENT_COMMAND_STATUS:
        if (hci_event_command_status_get_command_opcode(packet) == hci_le_set_phy.opcode) {
            LOG("LE Set PHY status 0x%02x", hci_event_command_status_get_status(packet));
        }
        break;
    case HCI_EVENT_ENCRYPTION_CHANGE:
        LOG("encryption change: status 0x%02x, enabled %u",
            hci_event_encryption_change_get_status(packet),
            hci_event_encryption_change_get_encryption_enabled(packet));
        if (hci_event_encryption_change_get_encryption_enabled(packet)) {
            ble_diagnostics_on_encrypted(hci_event_encryption_change_get_connection_handle(packet));
        }
        break;
    case HCI_EVENT_DISCONNECTION_COMPLETE:
        LOG("disconnected, reason 0x%02x", hci_event_disconnection_complete_get_reason(packet));
        ble_diagnostics_on_disconnected();
        gatt_bridge_disconnected();
        connected = false;
        config.listener.on_disconnected(config.listener.context);
        if (advertising_wanted) {
            begin_advertising();
        }
        break;
    default:
        if (!is_noisy_event(hci_event_packet_get_type(packet))) {
            printf("hci event 0x%02x:", hci_event_packet_get_type(packet));
            for (uint16_t index = 0; index < size && index < 32; index++) {
                printf(" %02x", packet[index]);
            }
            printf("\n");
        }
        break;
    }
}

int ble_peripheral_start(const ble_peripheral_config_t *peripheral_config) {
    config = *peripheral_config;

    gatt_bridge_init(&config.gatt);
    l2cap_init();
    att_server_init(profile_data, gatt_bridge_read, gatt_bridge_write);
    att_server_register_packet_handler(gatt_bridge_handle_att_event);

    hci_registration.callback = handle_hci_event;
    hci_add_event_handler(&hci_registration);

    config.platform.power_on(config.profile);
    return 0;
}
