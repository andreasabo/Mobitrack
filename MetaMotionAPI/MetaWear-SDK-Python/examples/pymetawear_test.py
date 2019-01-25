# usage: python log_to_file.py [seconds_to_stream_for] [file_name]
from pymetawear.client import MetaWearClient
from time import sleep
import datetime, time
import sys, os

device_mac = 'F7:83:98:15:21:07'
seconds_to_stream_for = 200

c = MetaWearClient(device_mac)
# Set data rate to 100 Hz and measuring range to +/- 2g
c.accelerometer.set_settings(data_rate=100.0, data_range=2)
c.gyroscope.set_settings(data_rate=100.0, data_range=500.0)

accel_data_to_export = []
gyro_data_to_export = []

filename = str(int(time.time())) + '.txt'

# Parse command line arguments
if len(sys.argv) > 1:
    seconds_to_stream_for = float(sys.argv[1])
    if len(sys.argv) > 2:
        filename = str(sys.argv[2])

filename = "small_exercise_ra_01.txt"
data_folder_name = "data_newSensorOrientation"

if not os.path.exists(data_folder_name):
    os.mkdir(data_folder_name)
    print("Directory " , data_folder_name ,  " created ")
else:
    print("Directory " , data_folder_name ,  " already exists")


def acc_callback(data):
    """Handle a (epoch, (x,y,z)) accelerometer tuple."""
    sensor_val = data['value']
    accel_data_to_export.append("%d,%f,%f,%f" % (data['epoch'], sensor_val.x, sensor_val.y, sensor_val.z))


def gyro_callback(data):
    """Handle a (epoch, (x,y,z)) gyroscope tuple."""
    sensor_val = data['value']
    gyro_data_to_export.append("%d,%f,%f,%f" % (data['epoch'], sensor_val.x, sensor_val.y, sensor_val.z))


print("logging...")
# Enable notifications and register a callback for them.
c.accelerometer.notifications(acc_callback)
c.gyroscope.notifications(gyro_callback)
sleep(seconds_to_stream_for)

# Unregister callbacks
c.accelerometer.notifications()
c.gyroscope.notifications()

# Log acceleration
with open(os.path.join(data_folder_name, 'accel_' + filename), 'w') as f:
    print(filename)
    f.write('timestamp, x, y, z\n')
    f.write('\n'.join(accel_data_to_export))

# Log gyro
gyro_file = os.path.join(data_folder_name, 'gyro_' + filename)
with open(gyro_file, 'w') as f:
    print(gyro_file)
    f.write('timestamp, x, y, z\n')
    f.write('\n'.join(gyro_data_to_export))
