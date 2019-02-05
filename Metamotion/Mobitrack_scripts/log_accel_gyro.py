# usage: python data_fuser.py [mac1] [mac2] ... [mac(n)]
from __future__ import print_function
from ctypes import c_void_p, cast, POINTER
from mbientlab.metawear import MetaWear, libmetawear, parse_value, cbindings
from time import sleep
import time
from threading import Event
from sys import argv
import os


seconds_to_stream = 100
filename = "ll_rest_01.txt"
data_folder_name = "../data/MetaMotion"


states = []
sensor_data = []

class State:
    def __init__(self, device):
        self.device = device
        self.callback = cbindings.FnVoid_VoidP_DataP(self.data_handler)
        self.processor = None

    def data_handler(self, ctx, data):
        values = parse_value(data, n_elem=2)
        time_stamp = data.contents.epoch
        data_current = [time_stamp, values[0].x, values[0].y, values[0].z, values[1].x, values[1].y, values[1].z]
        sensor_data.append("%d,%f,%f,%f,%f,%f,%f" % (time_stamp,  values[0].x, values[0].y, values[0].z, values[1].x, values[1].y, values[1].z))


    def setup(self):
        libmetawear.mbl_mw_settings_set_connection_parameters(self.device.board, 7.5, 7.5, 0, 6000)
        sleep(1.5)

        e = Event()

        def processor_created(context, pointer):
            self.processor = pointer
            e.set()

        fn_wrapper = cbindings.FnVoid_VoidP_VoidP(processor_created)

        acc = libmetawear.mbl_mw_acc_get_acceleration_data_signal(self.device.board)
        gyro = libmetawear.mbl_mw_gyro_bmi160_get_rotation_data_signal(self.device.board)

        signals = (c_void_p * 1)()
        signals[0] = gyro
        libmetawear.mbl_mw_dataprocessor_fuser_create(acc, signals, 1, None, fn_wrapper)
        e.wait()
        libmetawear.mbl_mw_datasignal_subscribe(self.processor, None, self.callback)

    def start(self):
        libmetawear.mbl_mw_gyro_bmi160_enable_rotation_sampling(self.device.board)
        libmetawear.mbl_mw_acc_enable_acceleration_sampling(self.device.board)

        libmetawear.mbl_mw_gyro_bmi160_start(self.device.board)
        libmetawear.mbl_mw_acc_start(self.device.board)



# Connect to all devices provided as command line args
for i in range(len(argv) - 1):
    d = MetaWear(argv[i + 1])
    d.connect()
    print("Connected to " + d.address)
    states.append(State(d))

for s in states:
    print("Configuring %s" % (s.device.address))
    s.setup()

for s in states:
    s.start()

sleep(seconds_to_stream)

print("Resetting devices")
events = []
for s in states:
    e = Event()
    events.append(e)

    s.device.on_disconnect = lambda s: e.set()
    libmetawear.mbl_mw_debug_reset(s.device.board)

for e in events:
    e.wait()



if not os.path.exists(data_folder_name):
    os.mkdir(data_folder_name)
    print("Directory " , data_folder_name ,  " created ")
else:
    print("Directory " , data_folder_name ,  " already exists")

#print(sensor_data)
# Log data to file
with open(os.path.join(data_folder_name, 'data_' + filename), 'w') as f:
    print(filename)
    f.write('timestamp, accel_x, accel_y, accel_z, gyro_x, gyro_y, gyro_z\n')
    f.write('\n'.join(sensor_data))