#include "ble/ble_diagnostics.h"

#include "platform/log.h"

#ifdef NORDICPAD_DIAGNOSTIC_LINK_PROBE
#define LINK_PROBE_INTERVAL_MS 500
#define CHANNEL_MAP_REPLY_OFFSET 3
#define QOS_SUBEVENT 0x80
#define QOS_OFFSET_COUNTER 5
#define QOS_OFFSET_OK 8
#define QOS_OFFSET_ERROR 10
#define QOS_OFFSET_FLAGS 14

static const hci_cmd_t vs_qos_report_enable = {HCI_OPCODE(OGF_VENDOR, 0x104), "1"};
static btstack_timer_source_t probe_timer;
static hci_con_handle_t probe_connection;
static bool probe_active;
static bool probe_reads_rssi;
static bool qos_enabled;
static bool qos_has_last;
static uint16_t qos_last_counter;
static uint32_t qos_events;
static uint32_t qos_missed;
static uint32_t qos_crc_ok;
static uint32_t qos_crc_error;
static uint32_t qos_timeouts;

static void qos_reset_counts(void) {
    qos_events = 0;
    qos_missed = 0;
    qos_crc_ok = 0;
    qos_crc_error = 0;
    qos_timeouts = 0;
}

static void qos_record(const uint8_t *packet) {
    uint16_t counter = little_endian_read_16(packet, QOS_OFFSET_COUNTER);
    if (qos_has_last) {
        qos_missed += (uint16_t)(counter - qos_last_counter - 1);
    }
    qos_has_last = true;
    qos_last_counter = counter;
    qos_events++;
    qos_crc_ok += little_endian_read_16(packet, QOS_OFFSET_OK);
    qos_crc_error += little_endian_read_16(packet, QOS_OFFSET_ERROR);
    qos_timeouts += packet[QOS_OFFSET_FLAGS] & 1;
}

static void qos_log_and_reset(void) {
    LOG("probe qos events %u missed %u crc_ok %u crc_err %u rx_timeout %u",
        (unsigned)qos_events,
        (unsigned)qos_missed,
        (unsigned)qos_crc_ok,
        (unsigned)qos_crc_error,
        (unsigned)qos_timeouts);
    qos_reset_counts();
}

static void probe_tick(btstack_timer_source_t *timer) {
    if (!probe_active) {
        return;
    }
    if (!qos_enabled) {
        qos_enabled = true;
        hci_send_cmd(&vs_qos_report_enable, 1);
    } else if (qos_events > 0 || qos_missed > 0) {
        qos_log_and_reset();
    } else if (probe_reads_rssi) {
        gap_read_rssi(probe_connection);
    } else {
        hci_send_cmd(&hci_le_read_channel_map, probe_connection);
    }
    probe_reads_rssi = !probe_reads_rssi;
    btstack_run_loop_set_timer(timer, LINK_PROBE_INTERVAL_MS);
    btstack_run_loop_add_timer(timer);
}

static void probe_start(hci_con_handle_t connection) {
    probe_connection = connection;
    probe_active = true;
    probe_reads_rssi = true;
    probe_timer.process = probe_tick;
    btstack_run_loop_set_timer(&probe_timer, LINK_PROBE_INTERVAL_MS);
    btstack_run_loop_add_timer(&probe_timer);
}

static void probe_stop(void) {
    probe_active = false;
    qos_enabled = false;
    qos_has_last = false;
    qos_reset_counts();
    btstack_run_loop_remove_timer(&probe_timer);
}

static void probe_log_command_complete(const uint8_t *packet) {
    uint16_t opcode = hci_event_command_complete_get_command_opcode(packet);
    const uint8_t *parameters = hci_event_command_complete_get_return_parameters(packet);
    if (opcode == vs_qos_report_enable.opcode) {
        LOG("probe qos enable status %02x", parameters[0]);
    } else if (opcode == hci_le_read_channel_map.opcode) {
        LOG("probe channel map status %02x map %02x%02x%02x%02x%02x",
            parameters[0],
            parameters[CHANNEL_MAP_REPLY_OFFSET],
            parameters[CHANNEL_MAP_REPLY_OFFSET + 1],
            parameters[CHANNEL_MAP_REPLY_OFFSET + 2],
            parameters[CHANNEL_MAP_REPLY_OFFSET + 3],
            parameters[CHANNEL_MAP_REPLY_OFFSET + 4]);
    }
}
#endif

#ifdef NORDICPAD_DIAGNOSTIC_REQUEST_INTERVAL
#define REQUEST_SUPERVISION_TIMEOUT 200

static void request_connection_interval(hci_con_handle_t connection) {
    LOG("requesting connection interval %u", NORDICPAD_DIAGNOSTIC_REQUEST_INTERVAL);
    gap_request_connection_parameter_update(connection,
                                            NORDICPAD_DIAGNOSTIC_REQUEST_INTERVAL,
                                            NORDICPAD_DIAGNOSTIC_REQUEST_INTERVAL,
                                            0,
                                            REQUEST_SUPERVISION_TIMEOUT);
}
#endif

#ifdef NORDICPAD_DIAGNOSTIC_LLPM
static const hci_cmd_t vs_llpm_mode_set = {HCI_OPCODE(OGF_VENDOR, 0x101), "1"};
#endif

#ifdef NORDICPAD_DIAGNOSTIC_TX_POWER_DBM
#define VS_TX_POWER_ADVERTISING 0
#define VS_TX_POWER_CONNECTION 2
#define TX_POWER_DELAY_MS 300

static const hci_cmd_t vs_write_tx_power = {HCI_OPCODE(OGF_VENDOR, 0x0E), "1H1"};
static btstack_timer_source_t connection_power_timer;
static btstack_timer_source_t advertising_power_timer;
static hci_con_handle_t power_connection;

static void apply_connection_power(btstack_timer_source_t *timer) {
    UNUSED(timer);
    hci_send_cmd(&vs_write_tx_power, VS_TX_POWER_CONNECTION, power_connection, NORDICPAD_DIAGNOSTIC_TX_POWER_DBM);
}

static void apply_advertising_power(btstack_timer_source_t *timer) {
    UNUSED(timer);
    hci_send_cmd(&vs_write_tx_power, VS_TX_POWER_ADVERTISING, 0, NORDICPAD_DIAGNOSTIC_TX_POWER_DBM);
}

static void schedule_tx_power(btstack_timer_source_t *timer, void (*handler)(btstack_timer_source_t *)) {
    timer->process = handler;
    btstack_run_loop_set_timer(timer, TX_POWER_DELAY_MS);
    btstack_run_loop_add_timer(timer);
}
#endif

void ble_diagnostics_on_ready(void) {
#ifdef NORDICPAD_DIAGNOSTIC_LLPM
    hci_send_cmd(&vs_llpm_mode_set, 1);
#endif
#ifdef NORDICPAD_DIAGNOSTIC_TX_POWER_DBM
    schedule_tx_power(&advertising_power_timer, apply_advertising_power);
#endif
}

void ble_diagnostics_on_connected(hci_con_handle_t connection) {
    UNUSED(connection);
#ifdef NORDICPAD_DIAGNOSTIC_LINK_PROBE
    probe_start(connection);
#endif
#ifdef NORDICPAD_DIAGNOSTIC_TX_POWER_DBM
    power_connection = connection;
    schedule_tx_power(&connection_power_timer, apply_connection_power);
#endif
}

void ble_diagnostics_on_encrypted(hci_con_handle_t connection) {
    UNUSED(connection);
#ifdef NORDICPAD_DIAGNOSTIC_REQUEST_INTERVAL
    request_connection_interval(connection);
#endif
}

void ble_diagnostics_on_disconnected(void) {
#ifdef NORDICPAD_DIAGNOSTIC_LINK_PROBE
    probe_stop();
#endif
}

void ble_diagnostics_on_hci_event(const uint8_t *packet) {
    UNUSED(packet);
#if defined(NORDICPAD_DIAGNOSTIC_LINK_PROBE) || defined(NORDICPAD_DIAGNOSTIC_LLPM) || defined(NORDICPAD_DIAGNOSTIC_TX_POWER_DBM)
    switch (hci_event_packet_get_type(packet)) {
    case HCI_EVENT_COMMAND_COMPLETE: {
        uint16_t opcode = hci_event_command_complete_get_command_opcode(packet);
        UNUSED(opcode);
#ifdef NORDICPAD_DIAGNOSTIC_LINK_PROBE
        probe_log_command_complete(packet);
#endif
#ifdef NORDICPAD_DIAGNOSTIC_LLPM
        if (opcode == vs_llpm_mode_set.opcode) {
            LOG("llpm enable status %02x", hci_event_command_complete_get_return_parameters(packet)[0]);
        }
#endif
#ifdef NORDICPAD_DIAGNOSTIC_TX_POWER_DBM
        if (opcode == vs_write_tx_power.opcode) {
            LOG("tx power write status %02x", hci_event_command_complete_get_return_parameters(packet)[0]);
        }
#endif
        break;
    }
#ifdef NORDICPAD_DIAGNOSTIC_LINK_PROBE
    case HCI_EVENT_VENDOR_SPECIFIC:
        if (packet[2] == QOS_SUBEVENT) {
            qos_record(packet);
        }
        break;
    case GAP_EVENT_RSSI_MEASUREMENT:
        LOG("probe rssi %d", (int8_t)gap_event_rssi_measurement_get_rssi(packet));
        break;
#endif
    default:
        break;
    }
#endif
}
