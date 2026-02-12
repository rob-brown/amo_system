#include "joycon_client.h"
#include "logging.h"
#include "protocol_logger.h"
#include <string.h>
#include <stdio.h>

static joycon_state_t state = JOYCON_STATE_IDLE;
static bd_addr_t joycon_addr;
static uint16_t l2cap_control_cid = 0;
static uint16_t l2cap_interrupt_cid = 0;
static hci_con_handle_t hci_handle = HCI_CON_HANDLE_INVALID;

static btstack_packet_handler_t packet_handler = NULL;
static joycon_data_callback_t data_callback = NULL;
static joycon_state_callback_t state_callback = NULL;

static void set_state(joycon_state_t new_state) {
    if (state != new_state) {
        state = new_state;
        if (state_callback) {
            state_callback(new_state);
        }
    }
}

static void l2cap_packet_handler(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size) {
    if (packet_handler) {
        packet_handler(packet_type, channel, packet, size);
    }

    if (packet_type == HCI_EVENT_PACKET) {
        switch (hci_event_packet_get_type(packet)) {
            case L2CAP_EVENT_CHANNEL_OPENED: {
                uint16_t psm = l2cap_event_channel_opened_get_psm(packet);
                uint16_t local_cid = l2cap_event_channel_opened_get_local_cid(packet);
                uint8_t status = l2cap_event_channel_opened_get_status(packet);

                pico_log_infof("L2CAP channel opened: PSM 0x%04X, CID 0x%04X, status %d",
                              psm, local_cid, status);

                if (status != 0) {
                    pico_log_errorf("L2CAP connection failed: PSM 0x%04X, status %d", psm, status);
                    set_state(JOYCON_STATE_IDLE);
                    break;
                }

                if (psm == L2CAP_PSM_HID_CONTROL) {
                    l2cap_control_cid = local_cid;
                    set_state(JOYCON_STATE_CONTROL_CONNECTED);
                    pico_log_notice("Control channel connected, creating interrupt channel");

                    uint8_t int_status = l2cap_create_channel(l2cap_packet_handler, joycon_addr,
                                                               L2CAP_PSM_HID_INTERRUPT, 0xFFFF,
                                                               &l2cap_interrupt_cid);
                    if (int_status != ERROR_CODE_SUCCESS) {
                        pico_log_errorf("Failed to create interrupt channel: 0x%02x", int_status);
                        set_state(JOYCON_STATE_IDLE);
                    } else {
                        set_state(JOYCON_STATE_INTERRUPT_CONNECTING);
                    }
                } else if (psm == L2CAP_PSM_HID_INTERRUPT) {
                    l2cap_interrupt_cid = local_cid;
                    pico_log_notice("Interrupt channel connected");

                    if (l2cap_control_cid != 0) {
                        set_state(JOYCON_STATE_READY);
                        pico_log_notice("Joy-Con connected and ready");
                    }
                }
                break;
            }

            case L2CAP_EVENT_CHANNEL_CLOSED: {
                uint16_t local_cid = l2cap_event_channel_closed_get_local_cid(packet);

                pico_log_infof("L2CAP channel closed: CID 0x%04X", local_cid);

                if (local_cid == l2cap_control_cid) {
                    l2cap_control_cid = 0;
                }
                if (local_cid == l2cap_interrupt_cid) {
                    l2cap_interrupt_cid = 0;
                }

                if (l2cap_control_cid == 0 && l2cap_interrupt_cid == 0) {
                    set_state(JOYCON_STATE_IDLE);
                    hci_handle = HCI_CON_HANDLE_INVALID;
                }
                break;
            }
        }
    } else if (packet_type == L2CAP_DATA_PACKET) {
        if (channel == l2cap_interrupt_cid && size > 0) {
            log_input_report(packet, size);
            if (data_callback) {
                data_callback(packet, size);
            }
        }
    }
}

void joycon_client_init(void) {
    state = JOYCON_STATE_IDLE;
    memset(joycon_addr, 0, 6);
    l2cap_control_cid = 0;
    l2cap_interrupt_cid = 0;
    hci_handle = HCI_CON_HANDLE_INVALID;

    l2cap_init();
}

void joycon_client_set_packet_handler(btstack_packet_handler_t handler) {
    packet_handler = handler;
}

void joycon_client_set_data_callback(joycon_data_callback_t callback) {
    data_callback = callback;
}

void joycon_client_set_state_callback(joycon_state_callback_t callback) {
    state_callback = callback;
}

bool joycon_client_connect(bd_addr_t addr) {
    if (state != JOYCON_STATE_IDLE && state != JOYCON_STATE_DISCOVERED) {
        pico_log_warning("Cannot connect: already connecting or connected");
        return false;
    }

    memcpy(joycon_addr, addr, 6);
    set_state(JOYCON_STATE_CONTROL_CONNECTING);

    pico_log_infof("Connecting to Joy-Con: %s", bd_addr_to_str(addr));

    uint8_t status = l2cap_create_channel(l2cap_packet_handler, joycon_addr,
                                          L2CAP_PSM_HID_CONTROL, 0xFFFF, &l2cap_control_cid);

    if (status != ERROR_CODE_SUCCESS) {
        pico_log_errorf("Failed to create control channel: 0x%02x", status);
        set_state(JOYCON_STATE_IDLE);
        return false;
    }

    return true;
}

void joycon_client_disconnect(void) {
    if (l2cap_control_cid != 0) {
        l2cap_disconnect(l2cap_control_cid);
    }
    if (l2cap_interrupt_cid != 0) {
        l2cap_disconnect(l2cap_interrupt_cid);
    }
}

joycon_state_t joycon_client_get_state(void) {
    return state;
}

bool joycon_client_is_connected(void) {
    return state == JOYCON_STATE_READY;
}

bool joycon_client_send_data(const uint8_t *data, uint16_t size) {
    if (!joycon_client_is_connected() || l2cap_interrupt_cid == 0) {
        pico_log_warning("Cannot send data: not connected");
        return false;
    }

    log_output_report(data, size);

    uint8_t status = l2cap_send(l2cap_interrupt_cid, (uint8_t *)data, size);
    if (status != 0) {
        pico_log_warningf("L2CAP send failed: status=%d", status);
        return false;
    }

    return true;
}

void joycon_client_get_addr(bd_addr_t addr) {
    memcpy(addr, joycon_addr, 6);
}
