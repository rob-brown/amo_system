#!/usr/bin/env python3

import cv2
import sys
import os
import numpy
import time
from datetime import datetime, timedelta

debug_mode = False

def crop(img, top=0.0, left=0.0, bottom=1.0, right=1.0):
    height, width, _ = img.shape
    cropped = img[int(top * height):int(bottom * height), int(left * width):int(right * height)]
    return cropped

def crop_px(img, top, left, bottom, right):
    cropped = img[top:bottom, left:right]
    return cropped

def box(img, top=0.0, left=0.0, bottom=1.0, right=1.0):
    height, width, _ = img.shape
    box = cv2.rectangle(img, (int(left * width), int(top * height)), (int(right * width), int(bottom * height)), (0, 0, 255), 2)
    return box

def find(img, template, confidence=0.8):
    result = cv2.matchTemplate(img, template, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, (x, y) = cv2.minMaxLoc(result)
    h, w = (template.shape[0], template.shape[1])

    if max_val >= confidence:
        if debug_mode:
            cv2.rectangle(img, (x, y), (x + w, y + h), (255, 255, 255), 2)
            cv2.imwrite('/home/pi/find.png', img)
        return (((x, y), (x + w, y + h)), max_val, img.shape)
    else:
        return None

def count(img, template, confidence=0.89):
    result = cv2.matchTemplate(img, template, cv2.TM_CCOEFF_NORMED)
    locations = numpy.where(result >= confidence)
    count = 0
    h, w = (template.shape[0], template.shape[1])

    for loc in zip(*locations[::-1]):
        count += 1
        if debug_mode:
            cv2.rectangle(img, loc, (loc[0] + w, loc[1] + h), (255, 255, 255), 2)

    if debug_mode:
        cv2.imwrite('/home/pi/count.png', img)

    return count

def loop_until_gone(capture, template, timeout_delta, confidence=0.8):
    timeout_moment = datetime.now() + timeout_delta
    result = None

    while datetime.now() < timeout_moment:
        img = capture_image(capture)

        if img is None:
            sys.exit('Capture source is closed')

        result = find(img, template, confidence)
        if result is None:
            break

        # Sleep 100 ms
        time.sleep(0.1)

    return result

def loop_until_found(capture, template, timeout_delta, confidence=0.8):
    timeout_moment = datetime.now() + timeout_delta
    result = None

    while datetime.now() < timeout_moment:
        img = capture_image(capture)

        if img is None:
            sys.exit('Capture source is closed')

        result = find(img, template, confidence)
        if result is not None:
            break

        # Sleep 100 ms
        time.sleep(0.1)

    return result

def capture_image(capture):
    if capture.isOpened() == False:
        return None

    # Grab two images since one will be buffered and old.
    # Uses grab/retrieve instead of read so only one frame is decoded.

    _ = capture.grab()
    _ = capture.grab()
    success, img = capture.retrieve()

    if success:
        return img
    else:
        return None

## CLI

def default_capture():
    capture = cv2.VideoCapture('/dev/video0')

    # 0. CAP_PROP_POS_MSEC Current position of the video file in milliseconds.
    # 1. CAP_PROP_POS_FRAMES 0-based index of the frame to be decoded/captured next.
    # 2. CAP_PROP_POS_AVI_RATIO Relative position of the video file
    # 3. CAP_PROP_FRAME_WIDTH Width of the frames in the video stream.
    # 4. CAP_PROP_FRAME_HEIGHT Height of the frames in the video stream.
    # 5. CAP_PROP_FPS Frame rate.
    # 6. CAP_PROP_FOURCC 4-character code of codec.
    # 7. CAP_PROP_FRAME_COUNT Number of frames in the video file.
    # 8. CAP_PROP_FORMAT Format of the Mat objects returned by retrieve() .
    # 9. CAP_PROP_MODE Backend-specific value indicating the current capture mode.
    # 10. CAP_PROP_BRIGHTNESS Brightness of the image (only for cameras).
    # 11. CAP_PROP_CONTRAST Contrast of the image (only for cameras).
    # 12. CAP_PROP_SATURATION Saturation of the image (only for cameras).
    # 13. CAP_PROP_HUE Hue of the image (only for cameras).
    # 14. CAP_PROP_GAIN Gain of the image (only for cameras).
    # 15. CAP_PROP_EXPOSURE Exposure (only for cameras).
    # 16. CAP_PROP_CONVERT_RGB Boolean flags indicating whether images should be converted to RGB.
    # 17. CAP_PROP_WHITE_BALANCE Currently unsupported
    # 18. CAP_PROP_RECTIFICATION Rectification flag for stereo cameras (note: only supported by DC1394 v 2.x backend currently)

    if capture.isOpened():
        capture.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        capture.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        capture.set(cv2.CAP_PROP_FPS, 30)
        capture.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        return capture
    else:
        return None

def read_image(path):
    if not os.path.exists(path):
        write_error(f'No such file {path}')
        return None

    img = cv2.imread(path)

    if img is None:
        write_error(f'Not an image {path}')
        return None
    else:
        return img

def write_error(error):
    print(f'Error\t{error}')
    sys.stdout.flush()

def write_result(result):
    if result is None:
        print('None')
        sys.stdout.flush()
    else:
        (((x1, y1), (x2, y2)), confidence, (height, width, _)) = result
        print(f'Found\t{x1}\t{y1}\t{x2}\t{y2}\t{confidence}\t{width}\t{height}')
        sys.stdout.flush()

def find_command(capture, args):
    if len(args) < 2:
        write_error('Bad args')
        return

    path = args[1]
    template = read_image(path)

    if template is None:
        return

    if len(args) == 3:
        confidence = float(args[2])
    else:
        confidence = 0.8

    img = capture_image(capture)
    result = find(img, template, confidence)
    write_result(result)

def count_command(capture, args):
    if len(args) < 2:
        write_error('Bad args')
        return

    path = args[1]
    template = read_image(path)

    if template is None:
        return

    if len(args) == 3:
        confidence = float(args[2])
    else:
        confidence = 0.89

    img = capture_image(capture)
    result = count(img, template, confidence)
    print(f'Count\t{result}')
    sys.stdout.flush()

def count_crop_command(capture, args):
    if len(args) != 7:
        write_error('Bad args')
        return

    path = args[1]
    template = read_image(path)

    if template is None:
        return

    confidence = float(args[6])
    img = capture_image(capture)
    img = crop(img, top=float(args[2]), left=float(args[3]), bottom=float(args[4]), right=float(args[5]))
    result = count(img, template, confidence)
    print(f'Count\t{result}')
    sys.stdout.flush()

def on_appear_command(capture, args):
    if len(args) != 3:
        write_error('Bad args')
        return

    path = args[1]
    seconds = int(args[2])
    delta = timedelta(seconds=seconds)
    template = read_image(path)

    if template is None:
        return

    result = loop_until_found(capture, template, delta)
    write_result(result)

def on_disappear_command(capture, args):
    if len(args) != 3:
        write_error('Bad args')
        return

    path = args[1]
    seconds = int(args[2])
    delta = timedelta(seconds=seconds)
    template = read_image(path)

    if template is None:
        return

    result = loop_until_gone(capture, template, delta)
    write_result(result)

def capture_command(capture, args):
    if len(args) != 2:
        write_error('Bad args')
        return

    path = args[1]
    img = capture_image(capture)

    if img is None:
        write_error('Failed to capture image')
        return

    if cv2.imwrite(path, img):
        print('Success')
        sys.stdout.flush()
    else:
        write_error('Failed to write image')

def capture_crop_command(capture, args):
    if len(args) != 6:
        write_error('Bad args')
        return

    path = args[1]
    img = capture_image(capture)

    if img is None:
        write_error('Failed to capture image')
        return

    img = crop_px(img, int(args[3]), int(args[2]), int(args[5]), int(args[4]))

    if cv2.imwrite(path, img):
        print('Success')
        sys.stdout.flush()
    else:
        write_error('Failed to write image')

def pixel_command(capture, args):
    if len(args) < 2:
        write_error('Bad args')
        return

    img = capture_image(capture)

    if img is None:
        write_error('Failed to capture image')

    pixels = []

    for a in args[1:]:
        [x, y] = list(map(int, a.split(',')))
        pixel = img[y, x]
        pixels.append(','.join(map(str,pixel)))

    response = '\t'.join(pixels)

    print(f'Pixels\t{response}')
    sys.stdout.flush()

def debug_command(capture, args):
    if len(args) != 2:
        write_error('Bad args')
        return

    global debug_mode

    if args[1] == "on":
        debug_mode = True
        print('Debug mode on')
        sys.stdout.flush()
    elif args[1] == "off":
        debug_mode = False
        print('Debug mode off')
        sys.stdout.flush()

if __name__ == "__main__":
    source = default_capture()

    if source.isOpened() == False:
        sys.exit('No capture device')

#     print('''
#     Commands:
#         # Check if image visible now
#         visible <image_file>
#
#         # Count number of images appear
#         count <image_file>
#
#         # Count number of images appear in the cropped bounds
#         count_crop <image_file> <top %> <left %> <bottom %> <right %>
#
#         # Watch until images appears or times out
#         find <image_file> <seconds>
#
#         # Watch until images disappears or times out
#         gone <image_file> <seconds>
#
#         # Capture an image and write it to the given path.
#         capture <destination_file>
#
#         # Capture and crop an image and write it to the given path.
#         # Crop coordinates are in pixels.
#         capture <destination_file> <top> <left> <bottom> <right>
#
#         # Enable/diabled debug mode
#         debug <on|off>
#     ''')

    for line in sys.stdin:
        args = line.rstrip().split()

        if args == []:
            write_error(f'Empty command')
            continue

        command = args[0]

        if command == "visible":
            find_command(source, args)

        elif command == "count_crop":
            count_crop_command(source, args)

        elif command == "count":
            count_command(source, args)

        elif command == "find":
            on_appear_command(source, args)

        elif command == "gone":
            on_disappear_command(source, args)

        elif command == "pixels":
            pixel_command(source, args)

        elif command == "capture":
            capture_command(source, args)

        elif command == "capture_crop":
            capture_crop_command(source, args)

        elif command == "debug":
            debug_command(source, args)

        elif command == "quit" or command == "exit":
            break

        else:
            write_error(f'Unknown command {line}')

    source.release()
