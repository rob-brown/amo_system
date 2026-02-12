#include "bt_hid.h"
#include "bonding_storage.h"
#include "logging.h"
#include "reconnect_manager.h"
#include "pico/stdlib.h"
#include "pico/cyw43_arch.h"
#include "btstack.h"
#include <string.h>
#include <stdio.h>

#define HID_REPORT_BUFFER_SIZE 400
#define SDP_RECORD_SIZE 512

static const uint8_t hid_descriptor[] = {
    0x05, 0x01,
    0x15, 0x00,
    0x09, 0x04,
    0xA1, 0x01,
    0x85, 0x30,
    0x05, 0x01,
    0x05, 0x09,
    0x19, 0x01,
    0x29, 0x0A,
    0x15, 0x00,
    0x25, 0x01,
    0x75, 0x01,
    0x95, 0x0A,
    0x55, 0x00,
    0x65, 0x00,
    0x81, 0x02,
    0x05, 0x09,
    0x19, 0x0B,
    0x29, 0x0E,
    0x15, 0x00,
    0x25, 0x01,
    0x75, 0x01,
    0x95, 0x04,
    0x81, 0x02,
    0x75, 0x01,
    0x95, 0x02,
    0x81, 0x03,
    0x0B, 0x01, 0x00, 0x01, 0x00,
    0xA1, 0x00,
    0x0B, 0x30, 0x00, 0x01, 0x00,
    0x0B, 0x31, 0x00, 0x01, 0x00,
    0x0B, 0x32, 0x00, 0x01, 0x00,
    0x0B, 0x35, 0x00, 0x01, 0x00,
    0x15, 0x00,
    0x27, 0xFF, 0xFF, 0x00, 0x00,
    0x75, 0x10,
    0x95, 0x04,
    0x81, 0x02,
    0xC0,
    0x0B, 0x39, 0x00, 0x01, 0x00,
    0x15, 0x00,
    0x25, 0x07,
    0x35, 0x00,
    0x46, 0x3B, 0x01,
    0x65, 0x14,
    0x75, 0x04,
    0x95, 0x01,
    0x81, 0x02,
    0x05, 0x09,
    0x19, 0x0F,
    0x29, 0x12,
    0x15, 0x00,
    0x25, 0x01,
    0x75, 0x01,
    0x95, 0x04,
    0x81, 0x02,
    0x75, 0x08,
    0x95, 0x34,
    0x81, 0x03,
    0x06, 0x00, 0xFF,
    0x85, 0x21,
    0x09, 0x01,
    0x75, 0x08,
    0x95, 0x3F,
    0x81, 0x03,
    0x85, 0x81,
    0x09, 0x02,
    0x75, 0x08,
    0x95, 0x3F,
    0x81, 0x03,
    0x85, 0x01,
    0x09, 0x03,
    0x75, 0x08,
    0x95, 0x3F,
    0x91, 0x83,
    0x85, 0x10,
    0x09, 0x04,
    0x75, 0x08,
    0x95, 0x3F,
    0x91, 0x83,
    0x85, 0x80,
    0x09, 0x05,
    0x75, 0x08,
    0x95, 0x3F,
    0x91, 0x83,
    0x85, 0x82,
    0x09, 0x06,
    0x75, 0x08,
    0x95, 0x3F,
    0x91, 0x83,
    0xC0
};

static bt_hid_state_t state = BT_HID_STATE_IDLE;
static bt_hid_mode_t mode = BT_HID_MODE_SERVER;
static controller_state_t *controller = NULL;
static switch_protocol_t protocol;
static bt_hid_connection_callback_t connection_callback = NULL;

static uint16_t l2cap_control_cid = 0;
static uint16_t l2cap_interrupt_cid = 0;
static hci_con_handle_t hci_handle = HCI_CON_HANDLE_INVALID;
static bd_addr_t connected_addr;
static uint8_t auth_failure_count = 0;

static bd_addr_t reconnect_target_addr;
static bool reconnect_in_progress = false;

static uint8_t sdp_record[SDP_RECORD_SIZE];
static uint8_t report_buffer[HID_REPORT_BUFFER_SIZE];

static btstack_timer_source_t send_timer;
static uint32_t last_send_time = 0;
static bool can_send = true;

static btstack_packet_callback_registration_t hci_event_callback_registration;

static void create_sdp_record(void) {
    uint8_t *p = sdp_record;

    de_create_sequence(p);

    de_add_number(p, DE_UINT, DE_SIZE_16, BLUETOOTH_ATTRIBUTE_SERVICE_RECORD_HANDLE);
    de_add_number(p, DE_UINT, DE_SIZE_32, 0x00010001);

    de_add_number(p, DE_UINT, DE_SIZE_16, BLUETOOTH_ATTRIBUTE_SERVICE_CLASS_ID_LIST);
    uint8_t *class_list = de_push_sequence(p);
    de_add_number(class_list, DE_UUID, DE_SIZE_16, BLUETOOTH_SERVICE_CLASS_HUMAN_INTERFACE_DEVICE_SERVICE);
    de_pop_sequence(p, class_list);

    de_add_number(p, DE_UINT, DE_SIZE_16, BLUETOOTH_ATTRIBUTE_PROTOCOL_DESCRIPTOR_LIST);
    uint8_t *proto_list = de_push_sequence(p);
    uint8_t *l2cap_proto = de_push_sequence(proto_list);
    de_add_number(l2cap_proto, DE_UUID, DE_SIZE_16, BLUETOOTH_PROTOCOL_L2CAP);
    de_add_number(l2cap_proto, DE_UINT, DE_SIZE_16, L2CAP_PSM_HID_CONTROL);
    de_pop_sequence(proto_list, l2cap_proto);
    uint8_t *hidp_proto = de_push_sequence(proto_list);
    de_add_number(hidp_proto, DE_UUID, DE_SIZE_16, BLUETOOTH_PROTOCOL_HIDP);
    de_pop_sequence(proto_list, hidp_proto);
    de_pop_sequence(p, proto_list);

    de_add_number(p, DE_UINT, DE_SIZE_16, BLUETOOTH_ATTRIBUTE_BROWSE_GROUP_LIST);
    uint8_t *browse_list = de_push_sequence(p);
    de_add_number(browse_list, DE_UUID, DE_SIZE_16, BLUETOOTH_ATTRIBUTE_PUBLIC_BROWSE_ROOT);
    de_pop_sequence(p, browse_list);

    de_add_number(p, DE_UINT, DE_SIZE_16, BLUETOOTH_ATTRIBUTE_LANGUAGE_BASE_ATTRIBUTE_ID_LIST);
    uint8_t *lang_list = de_push_sequence(p);
    de_add_number(lang_list, DE_UINT, DE_SIZE_16, 0x656E);
    de_add_number(lang_list, DE_UINT, DE_SIZE_16, 0x006A);
    de_add_number(lang_list, DE_UINT, DE_SIZE_16, 0x0100);
    de_pop_sequence(p, lang_list);

    de_add_number(p, DE_UINT, DE_SIZE_16, BLUETOOTH_ATTRIBUTE_BLUETOOTH_PROFILE_DESCRIPTOR_LIST);
    uint8_t *profile_list = de_push_sequence(p);
    uint8_t *hid_profile = de_push_sequence(profile_list);
    de_add_number(hid_profile, DE_UUID, DE_SIZE_16, BLUETOOTH_SERVICE_CLASS_HUMAN_INTERFACE_DEVICE_SERVICE);
    de_add_number(hid_profile, DE_UINT, DE_SIZE_16, 0x0100);
    de_pop_sequence(profile_list, hid_profile);
    de_pop_sequence(p, profile_list);

    de_add_number(p, DE_UINT, DE_SIZE_16, BLUETOOTH_ATTRIBUTE_ADDITIONAL_PROTOCOL_DESCRIPTOR_LISTS);
    uint8_t *add_proto = de_push_sequence(p);
    uint8_t *add_proto_list = de_push_sequence(add_proto);
    uint8_t *l2cap_add = de_push_sequence(add_proto_list);
    de_add_number(l2cap_add, DE_UUID, DE_SIZE_16, BLUETOOTH_PROTOCOL_L2CAP);
    de_add_number(l2cap_add, DE_UINT, DE_SIZE_16, L2CAP_PSM_HID_INTERRUPT);
    de_pop_sequence(add_proto_list, l2cap_add);
    uint8_t *hidp_add = de_push_sequence(add_proto_list);
    de_add_number(hidp_add, DE_UUID, DE_SIZE_16, BLUETOOTH_PROTOCOL_HIDP);
    de_pop_sequence(add_proto_list, hidp_add);
    de_pop_sequence(add_proto, add_proto_list);
    de_pop_sequence(p, add_proto);

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0100);
    de_add_data(p, DE_STRING, strlen("Wireless Gamepad"), (uint8_t *)"Wireless Gamepad");

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0101);
    de_add_data(p, DE_STRING, strlen("Gamepad"), (uint8_t *)"Gamepad");

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0102);
    de_add_data(p, DE_STRING, strlen("Nintendo"), (uint8_t *)"Nintendo");

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0200);
    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0100);

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0201);
    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0111);

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0202);
    de_add_number(p, DE_UINT, DE_SIZE_8, 0x08);

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0203);
    de_add_number(p, DE_UINT, DE_SIZE_8, 0x00);

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0204);
    de_add_number(p, DE_BOOL, DE_SIZE_8, 1);

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0205);
    de_add_number(p, DE_BOOL, DE_SIZE_8, 1);

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0206);
    uint8_t *desc_list = de_push_sequence(p);
    uint8_t *desc_entry = de_push_sequence(desc_list);
    de_add_number(desc_entry, DE_UINT, DE_SIZE_8, 0x22);
    de_add_data(desc_entry, DE_STRING, sizeof(hid_descriptor), (uint8_t *)hid_descriptor);
    de_pop_sequence(desc_list, desc_entry);
    de_pop_sequence(p, desc_list);

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0207);
    uint8_t *langid_list = de_push_sequence(p);
    uint8_t *langid_entry = de_push_sequence(langid_list);
    de_add_number(langid_entry, DE_UINT, DE_SIZE_16, 0x0409);
    de_add_number(langid_entry, DE_UINT, DE_SIZE_16, 0x0100);
    de_pop_sequence(langid_list, langid_entry);
    de_pop_sequence(p, langid_list);

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x020B);
    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0100);

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x020C);
    de_add_number(p, DE_UINT, DE_SIZE_16, 0x0C80);

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x020D);
    de_add_number(p, DE_BOOL, DE_SIZE_8, 0);

    de_add_number(p, DE_UINT, DE_SIZE_16, 0x020E);
    de_add_number(p, DE_BOOL, DE_SIZE_8, 1);
}

static void send_timer_handler(btstack_timer_source_t *ts) {
    if (state != BT_HID_STATE_READY) {
        return;
    }

    if (!can_send) {
        btstack_run_loop_set_timer(ts, 5);
        btstack_run_loop_add_timer(ts);
        return;
    }

    uint32_t now = to_ms_since_boot(get_absolute_time());
    uint32_t interval = switch_protocol_get_send_interval_ms(&protocol);

    if (now - last_send_time >= interval) {
        bt_hid_send_report();
        last_send_time = now;
    }

    btstack_run_loop_set_timer(ts, interval);
    btstack_run_loop_add_timer(ts);
}

static void start_send_timer(void) {
    btstack_run_loop_remove_timer(&send_timer);
    btstack_run_loop_set_timer_handler(&send_timer, send_timer_handler);
    btstack_run_loop_set_timer(&send_timer, switch_protocol_get_send_interval_ms(&protocol));
    btstack_run_loop_add_timer(&send_timer);
    last_send_time = to_ms_since_boot(get_absolute_time());
}

static void stop_send_timer(void) {
    btstack_run_loop_remove_timer(&send_timer);
}

static void l2cap_packet_handler(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size);
static void handle_reconnect_callback(bool success, uint8_t attempts);

static void initiate_client_connection(bd_addr_t addr) {
    pico_log_noticef("Initiating client connection to %s", bd_addr_to_str(addr));

    mode = BT_HID_MODE_CLIENT;
    state = BT_HID_STATE_RECONNECTING;
    memcpy(connected_addr, addr, 6);

    uint8_t status = l2cap_create_channel(l2cap_packet_handler, addr,
                                          L2CAP_PSM_HID_CONTROL, 0xFFFF, &l2cap_control_cid);

    if (status != ERROR_CODE_SUCCESS) {
        pico_log_errorf("Failed to create control channel: 0x%02x", status);
        state = BT_HID_STATE_IDLE;
        reconnect_manager_on_failure(status);
    }
}

static void handle_reconnect_callback(bool success, uint8_t attempts) {
    if (success) {
        pico_log_noticef("Reconnection succeeded after %d attempts", attempts);
        auth_failure_count = 0;
        reconnect_in_progress = false;
    } else {
        if (reconnect_manager_is_active()) {
            pico_log_noticef("Reconnection attempt %d failed, retrying", attempts);
            initiate_client_connection(reconnect_target_addr);
        } else {
            pico_log_criticalf("Reconnection failed after %d attempts, falling back to advertising", attempts);
            reconnect_in_progress = false;
            bt_hid_start_advertising();
        }
    }
}

static void l2cap_packet_handler(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size) {
    pico_log_debugf("l2cap_packet_handler: type=%d, event=0x%02X",
                    packet_type,
                    packet_type == HCI_EVENT_PACKET ? hci_event_packet_get_type(packet) : 0xFF);

    if (packet_type == HCI_EVENT_PACKET) {
        switch (hci_event_packet_get_type(packet)) {
            case L2CAP_EVENT_INCOMING_CONNECTION: {
                uint16_t psm = l2cap_event_incoming_connection_get_psm(packet);
                uint16_t local_cid = l2cap_event_incoming_connection_get_local_cid(packet);
                hci_con_handle_t handle = l2cap_event_incoming_connection_get_handle(packet);

                pico_log_noticef("L2CAP incoming connection PSM 0x%04X, CID 0x%04X", psm, local_cid);

                l2cap_accept_connection(local_cid);

                if (psm == L2CAP_PSM_HID_CONTROL) {
                    l2cap_control_cid = local_cid;
                    hci_handle = handle;
                    state = BT_HID_STATE_CONTROL_CONNECTED;
                } else if (psm == L2CAP_PSM_HID_INTERRUPT) {
                    l2cap_interrupt_cid = local_cid;
                }
                break;
            }

            case L2CAP_EVENT_CHANNEL_OPENED: {
                uint16_t psm = l2cap_event_channel_opened_get_psm(packet);
                uint16_t local_cid = l2cap_event_channel_opened_get_local_cid(packet);
                uint8_t status = l2cap_event_channel_opened_get_status(packet);

                pico_log_debugf("L2CAP channel opened: PSM 0x%04X, CID 0x%04X, status %d, mode=%d, state=%d",
                               psm, local_cid, status, mode, state);

                if (status != 0) {
                    pico_log_errorf("L2CAP connection failed: PSM 0x%04X, status %d", psm, status);

                    if (state == BT_HID_STATE_READY) {
                        pico_log_warning("Ignoring duplicate channel error while already READY");
                        break;
                    }

                    if (mode == BT_HID_MODE_CLIENT) {
                        if (status == L2CAP_CONNECTION_RESPONSE_RESULT_REFUSED_SECURITY) {
                            auth_failure_count++;
                            pico_log_warningf("Authentication failure count: %d", auth_failure_count);

                            if (auth_failure_count >= 3) {
                                pico_log_error("Too many auth failures, switching to advertising");
                                auth_failure_count = 0;
                                reconnect_manager_stop();
                                state = BT_HID_STATE_IDLE;
                                mode = BT_HID_MODE_SERVER;
                                bt_hid_start_advertising();
                                return;
                            }
                        }

                        state = BT_HID_STATE_IDLE;
                        reconnect_manager_on_failure(status);
                    }
                    break;
                }

                if (psm == L2CAP_PSM_HID_CONTROL) {
                    l2cap_control_cid = local_cid;
                    state = BT_HID_STATE_CONTROL_CONNECTED;
                    pico_log_notice("Control channel connected");

                    if (mode == BT_HID_MODE_CLIENT) {
                        pico_log_debug("Creating interrupt channel (CLIENT mode)");
                        uint8_t int_status = l2cap_create_channel(l2cap_packet_handler, connected_addr,
                                                                   L2CAP_PSM_HID_INTERRUPT, 0xFFFF,
                                                                   &l2cap_interrupt_cid);
                        if (int_status != ERROR_CODE_SUCCESS) {
                            pico_log_errorf("Failed to create interrupt channel: 0x%02x", int_status);
                            state = BT_HID_STATE_IDLE;
                            reconnect_manager_on_failure(int_status);
                        }
                    }
                } else if (psm == L2CAP_PSM_HID_INTERRUPT) {
                    l2cap_interrupt_cid = local_cid;
                    pico_log_notice("Interrupt channel connected");

                    if (l2cap_control_cid != 0) {
                        state = BT_HID_STATE_READY;
                        bool is_reconnect = (mode == BT_HID_MODE_CLIENT);
                        pico_log_noticef("Both channels ready, transitioning to READY state (mode=%d)", mode);
                        switch_protocol_set_connected(&protocol, is_reconnect);

                        gap_discoverable_control(0);
                        gap_connectable_control(0);

                        bonding_storage_save_last_connected(connected_addr);

                        if (mode == BT_HID_MODE_CLIENT) {
                            reconnect_manager_on_success();
                        }

                        if (connection_callback) {
                            connection_callback(true);
                        }

                        start_send_timer();
                    }
                }
                break;
            }

            case L2CAP_EVENT_CHANNEL_CLOSED: {
                uint16_t local_cid = l2cap_event_channel_closed_get_local_cid(packet);

                pico_log_debugf("L2CAP channel closed: CID 0x%04X (control=0x%04X, interrupt=0x%04X)",
                               local_cid, l2cap_control_cid, l2cap_interrupt_cid);

                if (local_cid == l2cap_control_cid) {
                    l2cap_control_cid = 0;
                    pico_log_notice("Control channel closed");
                }
                if (local_cid == l2cap_interrupt_cid) {
                    l2cap_interrupt_cid = 0;
                    pico_log_notice("Interrupt channel closed");
                }

                if (l2cap_control_cid == 0 && l2cap_interrupt_cid == 0) {
                    bool was_advertising = (state == BT_HID_STATE_ADVERTISING);
                    bool was_connected = (state == BT_HID_STATE_READY || state == BT_HID_STATE_CONTROL_CONNECTED);

                    state = BT_HID_STATE_IDLE;
                    hci_handle = HCI_CON_HANDLE_INVALID;
                    switch_protocol_set_disconnected(&protocol);
                    stop_send_timer();

                    if (connection_callback && was_connected) {
                        connection_callback(false);
                    }

                    if (was_advertising) {
                        pico_log_notice("Restarting advertising after L2CAP channel close");
                        bt_hid_start_advertising();
                    }
                }
                break;
            }

            case L2CAP_EVENT_CAN_SEND_NOW:
                can_send = true;
                break;
        }
    } else if (packet_type == L2CAP_DATA_PACKET) {
        if (channel == l2cap_interrupt_cid && size > 0) {
            uint16_t response_len = 0;

            switch_protocol_update_timer(&protocol, to_ms_since_boot(get_absolute_time()));

            if (switch_protocol_handle_output_report(&protocol, packet, size, report_buffer, &response_len)) {
                if (response_len > 0 && l2cap_interrupt_cid != 0) {
                    l2cap_send(l2cap_interrupt_cid, report_buffer, response_len);
                }
            }
        }
    }
}

static void hci_packet_handler(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size) {
    UNUSED(channel);
    UNUSED(size);

    if (packet_type != HCI_EVENT_PACKET) {
        return;
    }

    switch (hci_event_packet_get_type(packet)) {
        case BTSTACK_EVENT_STATE:
            if (btstack_event_state_get_state(packet) == HCI_STATE_WORKING) {
                pico_log_notice("BTstack ready");
            }
            break;

        case HCI_EVENT_CONNECTION_COMPLETE: {
            uint8_t status = hci_event_connection_complete_get_status(packet);
            if (status == 0) {
                bd_addr_t addr;
                hci_event_connection_complete_get_bd_addr(packet, addr);
                memcpy(connected_addr, addr, 6);
                hci_con_handle_t handle = hci_event_connection_complete_get_connection_handle(packet);
                hci_handle = handle;
                pico_log_noticef("Connection from %s (handle=0x%04X)", bd_addr_to_str(addr), handle);
            } else {
                pico_log_errorf("Connection failed with status 0x%02X", status);
            }
            break;
        }

        case HCI_EVENT_IO_CAPABILITY_REQUEST: {
            bd_addr_t event_addr;
            hci_event_io_capability_request_get_bd_addr(packet, event_addr);
            pico_log_noticef("IO capability request from %s", bd_addr_to_str(event_addr));
            break;
        }

        case HCI_EVENT_IO_CAPABILITY_RESPONSE: {
            pico_log_notice("IO capability response received");
            break;
        }

        case HCI_EVENT_SIMPLE_PAIRING_COMPLETE: {
            bd_addr_t event_addr;
            hci_event_simple_pairing_complete_get_bd_addr(packet, event_addr);
            uint8_t status = hci_event_simple_pairing_complete_get_status(packet);
            pico_log_noticef("Simple pairing complete for %s, status=0x%02X", bd_addr_to_str(event_addr), status);
            break;
        }

        case HCI_EVENT_USER_CONFIRMATION_REQUEST: {
            bd_addr_t event_addr;
            hci_event_user_confirmation_request_get_bd_addr(packet, event_addr);
            pico_log_noticef("SSP: Auto-confirming pairing for %s", bd_addr_to_str(event_addr));
            gap_ssp_confirmation_response(event_addr);
            break;
        }

        case HCI_EVENT_PIN_CODE_REQUEST: {
            bd_addr_t event_addr;
            hci_event_pin_code_request_get_bd_addr(packet, event_addr);
            pico_log_noticef("PIN code requested for %s (legacy pairing not supported)", bd_addr_to_str(event_addr));
            break;
        }

        case HCI_EVENT_LINK_KEY_REQUEST: {
            bd_addr_t event_addr;
            hci_event_link_key_request_get_bd_addr(packet, event_addr);
            pico_log_noticef("Link key requested for %s", bd_addr_to_str(event_addr));
            break;
        }

        case HCI_EVENT_LINK_KEY_NOTIFICATION: {
            pico_log_notice("Link key notification received");
            break;
        }

        case HCI_EVENT_DISCONNECTION_COMPLETE: {
            uint8_t reason = hci_event_disconnection_complete_get_reason(packet);
            pico_log_noticef("Disconnection complete (previous state=%d, mode=%d, reason=0x%02X)", state, mode, reason);
            l2cap_control_cid = 0;
            l2cap_interrupt_cid = 0;
            hci_handle = HCI_CON_HANDLE_INVALID;

            bool was_advertising = (state == BT_HID_STATE_ADVERTISING);
            bool was_connected = (state == BT_HID_STATE_READY || state == BT_HID_STATE_CONTROL_CONNECTED);
            bool is_reconnecting = (state == BT_HID_STATE_RECONNECTING || reconnect_in_progress);

            if (!is_reconnecting) {
                mode = BT_HID_MODE_SERVER;
            }
            state = BT_HID_STATE_IDLE;
            switch_protocol_set_disconnected(&protocol);
            stop_send_timer();

            if (connection_callback && was_connected) {
                connection_callback(false);
            }

            if (was_advertising) {
                pico_log_notice("Restarting advertising after disconnection");
                bt_hid_start_advertising();
            }
            break;
        }

        default:
            pico_log_debugf("HCI event 0x%02X", hci_event_packet_get_type(packet));
            break;
    }
}

void bt_hid_init(controller_state_t *ctrl, bt_hid_connection_callback_t callback) {
    controller = ctrl;
    connection_callback = callback;

    bonding_storage_init();
    reconnect_manager_init();

    bd_addr_t local_addr;
    gap_local_bd_addr(local_addr);

    switch_protocol_init(&protocol, controller, local_addr);

    l2cap_init();

    gap_set_bondable_mode(1);
    gap_ssp_set_enable(1);
    gap_ssp_set_io_capability(SSP_IO_CAPABILITY_NO_INPUT_NO_OUTPUT);
    gap_ssp_set_authentication_requirement(SSP_IO_AUTHREQ_MITM_PROTECTION_NOT_REQUIRED_GENERAL_BONDING);

    const btstack_link_key_db_t *link_key_db = bonding_storage_get_link_key_db();
    if (link_key_db) {
        hci_set_link_key_db(link_key_db);
        pico_log_notice("Link key database registered");
    } else {
        pico_log_error("Failed to get link key database");
    }

    gap_set_security_level(LEVEL_2);
    pico_log_notice("Security level set to LEVEL_2 (encryption + authentication)");

    l2cap_register_service(l2cap_packet_handler, L2CAP_PSM_HID_CONTROL, 0xFFFF, LEVEL_2);
    l2cap_register_service(l2cap_packet_handler, L2CAP_PSM_HID_INTERRUPT, 0xFFFF, LEVEL_2);

    create_sdp_record();
    sdp_init();
    sdp_register_service(sdp_record);

    hci_event_callback_registration.callback = hci_packet_handler;
    hci_add_event_handler(&hci_event_callback_registration);

    gap_set_class_of_device(BT_DEVICE_CLASS_GAMEPAD);
    gap_set_local_name(controller_get_name(controller->type));
    gap_discoverable_control(0);
    gap_connectable_control(0);

    gap_set_default_link_policy_settings(LM_LINK_POLICY_ENABLE_SNIFF_MODE);
    gap_set_allow_role_switch(true);

    hci_set_inquiry_mode(INQUIRY_MODE_RSSI_AND_EIR);
}

void bt_hid_start_advertising(void) {
    pico_log_debugf("bt_hid_start_advertising called, current state=%d", state);

    if (state == BT_HID_STATE_READY) {
        pico_log_warning("Cannot start advertising: already connected");
        return;
    }

    if (state == BT_HID_STATE_RECONNECTING) {
        pico_log_notice("Stopping reconnection attempt to start advertising");
        reconnect_manager_stop();
        state = BT_HID_STATE_IDLE;
        pico_log_debug("State changed to IDLE");
    }

    if (state != BT_HID_STATE_IDLE && state != BT_HID_STATE_ADVERTISING) {
        pico_log_warningf("Warning: starting advertising from state %d", state);
        state = BT_HID_STATE_IDLE;
    }

    pico_log_noticef("Starting advertising as %s", controller_get_name(controller->type));

    mode = BT_HID_MODE_SERVER;
    pico_log_debug("Calling gap_discoverable_control(1)");
    gap_discoverable_control(1);
    pico_log_debug("Calling gap_connectable_control(1)");
    gap_connectable_control(1);
    state = BT_HID_STATE_ADVERTISING;
    pico_log_debugf("Advertising started, state=%d", state);
}

void bt_hid_stop_advertising(void) {
    gap_discoverable_control(0);
    gap_connectable_control(0);

    if (state == BT_HID_STATE_ADVERTISING) {
        state = BT_HID_STATE_IDLE;
    }
}

void bt_hid_disconnect(void) {
    if (hci_handle != HCI_CON_HANDLE_INVALID) {
        gap_disconnect(hci_handle);
    }
}

bool bt_hid_send_report(void) {
    static uint32_t send_count = 0;
    static uint32_t last_fail_log = 0;

    if (state != BT_HID_STATE_READY || l2cap_interrupt_cid == 0) {
        uint32_t now = to_ms_since_boot(get_absolute_time());
        if (now - last_fail_log > 5000) {
            pico_log_warningf("Send report blocked: state=%d, cid=%d", state, l2cap_interrupt_cid);
            last_fail_log = now;
        }
        return false;
    }

    if (!can_send) {
        l2cap_request_can_send_now_event(l2cap_interrupt_cid);
        uint32_t now = to_ms_since_boot(get_absolute_time());
        if (now - last_fail_log > 5000) {
            pico_log_warning("Send report blocked: can_send=false");
            last_fail_log = now;
        }
        return false;
    }

    switch_protocol_update_timer(&protocol, to_ms_since_boot(get_absolute_time()));

    uint16_t len = switch_protocol_build_input_report(&protocol, report_buffer, sizeof(report_buffer));
    if (len == 0) {
        return false;
    }

    uint8_t status = l2cap_send(l2cap_interrupt_cid, report_buffer, len);
    if (status != 0) {
        can_send = false;
        l2cap_request_can_send_now_event(l2cap_interrupt_cid);
        pico_log_warningf("L2CAP send failed: status=%d", status);
        return false;
    }

    send_count++;
    if (send_count == 1 || send_count == 10 || send_count == 60 || (send_count % 600 == 0)) {
        pico_log_debugf("Sent report #%d", send_count);
    }

    return true;
}

bt_hid_state_t bt_hid_get_state(void) {
    return state;
}

bool bt_hid_is_connected(void) {
    return state == BT_HID_STATE_READY;
}

void bt_hid_process(void) {
}

switch_protocol_t *bt_hid_get_protocol(void) {
    return &protocol;
}

bool bt_hid_reconnect(bd_addr_t addr, reconnect_policy_t policy) {
    if (state == BT_HID_STATE_READY) {
        pico_log_warning("Cannot reconnect: already connected");
        return false;
    }

    if (state == BT_HID_STATE_ADVERTISING) {
        pico_log_notice("Stopping advertising to start reconnection");
        bt_hid_stop_advertising();
    }

    if (state == BT_HID_STATE_RECONNECTING) {
        pico_log_notice("Already reconnecting, stopping previous attempt");
        reconnect_manager_stop();
    }

    if (state != BT_HID_STATE_IDLE) {
        pico_log_warningf("Warning: reconnecting from state %d", state);
        state = BT_HID_STATE_IDLE;
    }

    memcpy(reconnect_target_addr, addr, 6);
    reconnect_in_progress = true;

    reconnect_manager_start(addr, policy, handle_reconnect_callback);
    initiate_client_connection(addr);

    return true;
}

void bt_hid_clear_bonding(void) {
    bonding_storage_clear();

    if (state == BT_HID_STATE_RECONNECTING) {
        reconnect_manager_stop();
        state = BT_HID_STATE_IDLE;
    }
}

bool bt_hid_get_bonding_status(bd_addr_t *addr) {
    if (!bonding_storage_is_bonded()) {
        return false;
    }

    if (addr) {
        bonding_storage_load_last_connected(*addr);
    }

    return true;
}
