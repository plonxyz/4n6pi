#!/bin/bash
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

# Check if the correct number of arguments are passed
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <message> [blink_cursor]"
    exit 1
fi

# Set the message
MESSAGE=$1

# Set the blink cursor option
if [ "$#" -eq 2 ]; then
    BLINK_CURSOR=$2
else
    BLINK_CURSOR=false
fi

# Run the Python script with the provided message and blink cursor option
python3 /usr/local/bin/lcd_writer.py "$MESSAGE" "$BLINK_CURSOR"
