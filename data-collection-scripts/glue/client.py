from __future__ import print_function
from glue.config import SOCKET

import asyncore
import collections
import logging
import socket
import time

MAX_MESSAGE_LENGTH = 1024
ADDRESS = SOCKET


class Client(asyncore.dispatcher):

    name = "Unnamed"
    purpose = "reader" # 'reader' or 'writer'

    def __init__(self):
        asyncore.dispatcher.__init__(self)
        self.log = logging.getLogger()
        self.create_socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.log.info('Connecting to host at %s', ADDRESS)
        self.connect(ADDRESS)
        self.outbox = collections.deque()

        # Send identification to server
        #self.say("/HELLO/" + self.name + "/" + self.purpose + "/")

    def say(self, message):
        self.outbox.append(message)

    def handle_connect(self):
        pass

    def setup_data(self):
        return

    def get_data(self):
        return

    def writable(self):
        return (len(self.outbox) > 0)

    def handle_write(self):
        if not self.outbox:
            return
        message = self.outbox.popleft()

        self.log.info('Writing message: %s', message)
        
        if len(message) > MAX_MESSAGE_LENGTH:
            raise ValueError('Message too long')
        
        self.send(message)

    # Clean up the message
    # Called in self.say(). Useful in the client class for stripping out dumb Xbee garbage data.
    def clean_message(self, message):
        return message

    
    def handle_read(self):
        message = self.recv(MAX_MESSAGE_LENGTH)
        self.log.info('Received message: %s', message)
        self.read_data(message)

    def read_data(self, message):
        return

    def handle_close(self):
        self.close()

def start_client(client=None): 
    logging.basicConfig(level=logging.INFO)
    if client is None:
        client = Client()
    client.setup_data()
    while 1:
        asyncore.poll(timeout=0.01)
        if client.purpose == 'writer':
            client.get_data()
