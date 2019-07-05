import re
import subprocess
from appcontroller import AppController

class CustomAppController(AppController):

    def __init__(self, *args, **kwargs):
        AppController.__init__(self, *args, **kwargs)

    def start(self):
        print "Calling the default controller to populate table entries"
        AppController.start(self)

    def stop(self):
        print self.readCounter('ipv4_lpm_counter', 0)
        print self.readCounter('ipv4_lpm_counter', 1)
        print self.readCounter('set_nhop_counter', 0)
        print self.readCounter('drop_counter', 0)
        print self.readCounter('set_dmac_counter', 0)
        AppController.stop(self)

    def readCounter(self, counter, idx, thrift_port=9090, sw=None):
        if sw: thrift_port = sw.thrift_port
        p = subprocess.Popen([self.cli_path, '--thrift-port', str(thrift_port)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = p.communicate(input="counter_read %s %d" % (counter, idx))
        terminal_lines = stdout.split('\n')
        value_line = next(x for x in terminal_lines if "=" in x)
        values = value_line.split('= ', 1)[1]
        return "Counter %s(%d): %s" % (counter, idx, values[values.find("(") + 1:values.find(")")])