# 4n6pi - Forensic Imager for Raspberry Pi
# Copyright (C) 2024 plonxyz
# https://github.com/plonxyz/4n6pi
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import smbus
import time
import sys


I2C_ADDR = 0x27  

# LCD commands
LCD_CHR = 1  
LCD_CMD = 0  
LCD_BACKLIGHT = 0x08  
LCD_NOBACKLIGHT = 0x00  
ENABLE = 0b00000100  

# Timing constants
E_PULSE = 0.0005
E_DELAY = 0.0005

# Initialize I2C (SMBus)
bus = smbus.SMBus(1)

def lcd_byte(bits, mode, backlight=LCD_BACKLIGHT):
    bits_high = mode | (bits & 0xF0) | backlight
    bits_low = mode | ((bits << 4) & 0xF0) | backlight

    bus.write_byte(I2C_ADDR, bits_high)
    lcd_toggle_enable(bits_high)

    bus.write_byte(I2C_ADDR, bits_low)
    lcd_toggle_enable(bits_low)

def lcd_toggle_enable(bits):
    time.sleep(E_DELAY)
    bus.write_byte(I2C_ADDR, (bits | ENABLE))
    time.sleep(E_PULSE)
    bus.write_byte(I2C_ADDR, (bits & ~ENABLE))
    time.sleep(E_DELAY)

def lcd_init(backlight=LCD_BACKLIGHT):
    lcd_byte(0x33, LCD_CMD, backlight)
    lcd_byte(0x32, LCD_CMD, backlight)
    lcd_byte(0x06, LCD_CMD, backlight)
    lcd_byte(0x0C, LCD_CMD, backlight)
    lcd_byte(0x28, LCD_CMD, backlight)
    lcd_byte(0x01, LCD_CMD, backlight)
    time.sleep(E_DELAY)

def lcd_string(message, line, backlight=LCD_BACKLIGHT):
    if line == 1:
        lcd_byte(0x80, LCD_CMD, backlight)
    elif line == 2:
        lcd_byte(0xC0, LCD_CMD, backlight)

    for char in message:
        lcd_byte(ord(char), LCD_CHR, backlight)

def lcd_backlight(state):
    if state:
        backlight = LCD_BACKLIGHT
    else:
        backlight = LCD_NOBACKLIGHT

    lcd_byte(0x00, LCD_CMD, backlight)

def lcd_blink_cursor(enable, backlight=LCD_BACKLIGHT):
    if enable:
        lcd_byte(0x0D, LCD_CMD, backlight)  # Display on, cursor on, blinking cursor on
    else:
        lcd_byte(0x0C, LCD_CMD, backlight)  # Display on, cursor off, blinking cursor off

if __name__ == "__main__":
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print("Usage: python3 lcd_test.py <message> [blink_cursor]")
        sys.exit(1)
    
    message = sys.argv[1]
    blink_cursor = len(sys.argv) == 3 and sys.argv[2].lower() == 'true'

    # Initialize display with backlight on
    lcd_init(LCD_BACKLIGHT)

    # Enable or disable blinking cursor
    lcd_blink_cursor(blink_cursor, LCD_BACKLIGHT)

    # Split the message into two lines if necessary
    lines = message.split('\\n')
    if len(lines) > 2:
        print("Message should not exceed 2 lines.")
        sys.exit(1)

    # Display the message
    lcd_string(lines[0], 1, LCD_BACKLIGHT)
    if len(lines) == 2:
        lcd_string(lines[1], 2, LCD_BACKLIGHT)

