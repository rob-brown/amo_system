#!/usr/bin/env python

import sys
from queue import Queue
from threading import Thread
from evdev import InputDevice, categorize, ecodes, list_devices

print_mailbox = Queue()
input_thread = None
connected = False

pdp_buttons = {
        "a": 306,
        "b": 305,
        "y": 304,
        "x": 307,
        "l1": 308,
        "l2": 310,
        "l3": 314,
        "r1": 309,
        "r2": 311,
        "r3": 315,
        "-": 312,
        "+": 313,
        "capture": 317,
        "home": 316,
        "dx": 16,
        "dy": 17,
        "lx": 0,
        "ly": 1,
        "rx": 2,
        "ry": 5,
        }

# XBOX left trigger is 2. Right trigger is 5. rx is 3. ry is 4. 

###############
## Input Job ##
###############

def input_job(device):
    try:
        global connected
        connected = True

        for event in device.read_loop():
            # This is not ideal since it won't disconnect until it receives an event.
            # Manual disconnect then reconnect to the same controller is not common.
            # So this is good enough.
            if connected == False:
                send_msg('>1\n+Disconnected by request')
                break

            # ???: Should I send other types?
            if event.type == ecodes.EV_KEY or event.type == ecodes.EV_ABS:
                # Builds a message with the metadata.
                # The caller will interpret the data.
                # Sent as a list to make the data smaller.
                lines = [
                    '>1',
                    '*3',
                    f':{event.type}',
                    f':{event.code}',
                    f':{event.value}',
                ]

                msg = '\n'.join(lines)
                send_msg(msg)
    except:
        send_msg('-Controller force disconnected')
        connected = False

def connect(args):
    global input_thread

    if len(args) < 2:
        send_msg('-Expected a device ID')
    elif input_thread != None and input_thread.is_alive():
        send_msg('-Another device already connected')
    else:
        index = int(args[1])
        device = all_devices()[index]
        input_thread = Thread(target=input_job, args=(device,), daemon=True)
        input_thread.start()
        send_msg('+OK')

def disconnect():
    global connected
    connected = False

#################
## Printer Job ##
#################

def printer_job():
    while True:
        # Expects a string in RESP format.
        # https://redis.io/docs/reference/protocol-spec/
        msg = print_mailbox.get()
        print(msg)
        sys.stdout.flush()

def send_msg(string):
    print_mailbox.put(string)

################
## Reader Job ##
################

def reader_job():
    for line in sys.stdin:
        args = line.rstrip().split()

        if args == []:
            continue

        command = args[0]

        if command == 'list':
            list()
        elif command == 'connect':
            connect(args)
        elif command == 'disconnect':
            disconnect()
        elif command == 'quit' or command == 'exit':
            break
        else:
            send_msg(f'-Unknown command {line}')

def all_devices():
    devices = []

    for path in list_devices():
        device = InputDevice(path)

        if device.uniq != '':
            devices.append(device)

    return devices

def list():
    devices = all_devices()
    count = len(devices)

    # Builds the message to send.
    lines = []
    lines.append(f'*{count}')

    for index, device in enumerate(devices):
        lines.append('%3')
        lines.append('+id')
        lines.append(f':{index}')
        lines.append('+name')
        lines.append(f'${len(device.name)}')
        lines.append(f'{device.name}')
        lines.append('+path')
        lines.append(f'${len(device.path)}')
        lines.append(f'{device.path}')

    msg = "\n".join(lines)
    send_msg(msg)

if __name__ == "__main__":
    printer_thread = Thread(target=printer_job, daemon=True)
    printer_thread.start()

    reader_thread = Thread(target=reader_job)
    reader_thread.start()
    reader_thread.join()
