#!/usr/bin/env python

import sys
from queue import Queue
from threading import Thread
from evdev import InputDevice, categorize, ecodes, list_devices, util

print_mailbox = Queue()
input_thread = None
connected = False

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

            types = [ecodes.EV_SYN, ecodes.EV_KEY, ecodes.EV_ABS]

            if event.type in types:
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
        send_msg('-Expected a device path')
    elif input_thread != None and input_thread.is_alive():
        send_msg('-Another device already connected')
    elif util.is_device(args[1]):
        device = InputDevice(args[1])
        input_thread = Thread(target=input_job, args=(device,), daemon=True)
        input_thread.start()
        lines = [
            '*2',
            '+Connected',
            '%3',
            '+id',
            f'${len(device.uniq)}',
            f'{device.uniq}',
            '+name',
            f'${len(device.name)}',
            f'{device.name}',
            '+path',
            f'${len(device.path)}',
            f'{device.path}',
        ]
        msg = '\n'.join(lines)
        send_msg(msg)
    else:
        send_msg('-No such device')

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
        elif command == 'capabilities':
            capabilities(args)
        elif command == 'quit' or command == 'exit':
            break
        else:
            send_msg(f'-Unknown command {line}')

def all_devices():
    devices = []

    for path in list_devices():
        devices.append(InputDevice(path))

    devices = sorted(devices, key=lambda x: x.path)

    return devices

def capabilities(args):
    if len(args) < 2:
        send_msg('-Expected a device path')
    elif util.is_device(args[1]):
        path = args[1]
        device = InputDevice(path)
        capabilities = device.capabilities()
        
        lines = []
        lines.append('%2')

        buttons = capabilities.get(ecodes.EV_KEY, [])
        axes = capabilities.get(ecodes.EV_ABS, [])

        lines.append('+buttons')
        lines.append(f'*{len(buttons)}')

        for code in buttons:
            lines.append(f':{code}')

        lines.append('+axes')
        lines.append(f'*{len(axes)}')

        for code, info in axes:
            lines.append('%4')
            lines.append('+code')
            lines.append(f':{code}')
            lines.append('+min')
            lines.append(f':{info.min}')
            lines.append('+max')
            lines.append(f':{info.max}')
            lines.append('+deadzone')
            lines.append(f':{info.flat}')

        msg = '\n'.join(lines)
        send_msg(msg)
    else:
        send_msg('-No such device')

def list():
    devices = all_devices()
    count = len(devices)

    # Builds the message to send.
    lines = []
    lines.append(f'*{count}')

    for device in devices:
        id = device.uniq or 'null'
        lines.append('%3')
        lines.append('+id')
        lines.append(f'${len(id)}')
        lines.append(f'{id}')
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
