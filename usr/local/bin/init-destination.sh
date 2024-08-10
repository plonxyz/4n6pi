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

yaml_file="/mnt/usb/Imager_config.yaml"

# Check if the s3-config section exists
if yq e '.s3-config' "$yaml_file" > /dev/null; then
  # Extract the s3-config details from the YAML file
  access_key=$(yq e '.system.s3-config.access-key' "$yaml_file")
  secret_key=$(yq e '.system.s3-config.secret-key' "$yaml_file")
  s3_server=$(yq e '.system.s3-config.s3-server' "$yaml_file")
  bucket_name=$(yq e '.system.s3-config.bucketname' "$yaml_file")
  bucket_location=$(yq e '.system.s3-config.bucketlocation' "$yaml_file")
  use_https=$(yq e '.system.s3-config.use-https' "$yaml_file")
  # Create the .s3cfg file with the extracted details
  cat <<EOL > /root/.s3cfg
[default]
access_key = $access_key
secret_key = $secret_key
host_base = $s3_server
host_bucket = $bucket_name
bucket_location = $bucket_location
use_https = $use_https
EOL

  echo ".s3cfg file created successfully at /root/.s3cfg"
else
  echo "s3-config section not found in the YAML file."
fi
