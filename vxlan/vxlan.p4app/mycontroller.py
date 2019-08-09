from appcontroller import AppController

class CustomAppController(AppController):

    def __init__(self, *args, **kwargs):
        AppController.__init__(self, *args, **kwargs)

    def start(self):
        print "Calling the default controller to populate table entries"
        AppController.loadCommands(self)
        AppController.sendGeneratedCommands(self)
        self.net.staticArp()
        s1 = self.net.get('s1')
        s1.cmd("ifconfig s1-eth2 hw ether 00:aa:00:01:00:02")
        s2 = self.net.get('s2')
        s2.cmd("ifconfig s2-eth2 hw ether 00:aa:00:02:00:03")

    def stop(self):
        AppController.stop(self)