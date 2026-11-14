#include "ble/ble_link_key.h"

#include "btstack.h"
#include "platform/log.h"

void ble_link_key_answer_request(const uint8_t *hci_event, const ble_link_key_provider_t *provider) {
    hci_con_handle_t connection = hci_subevent_le_long_term_key_request_get_connection_handle(hci_event);
    uint8_t link_key[BLE_LINK_KEY_SIZE];

    if (provider->provide(provider->context, link_key)) {
        LOG("encryption requested: answering with the stored link key");
        hci_send_cmd(&hci_le_long_term_key_request_reply, connection, link_key);
        return;
    }

    LOG("encryption requested: no link key stored");
    hci_send_cmd(&hci_le_long_term_key_negative_reply, connection);
}
