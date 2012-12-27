# Stolen, then hacked to bits, from:
# http://stackoverflow.com/questions/3670127/python-socketserver-sending-to-multiple-clients
#
# The "chat" server has been modified to use unix sockets, since we don't care about
# reliability locally. It's all about raw freaking speed.

from __future__ import print_function
from glue.config import SOCKET

import asyncore
import collections
import logging
import socket
import os

MAX_MESSAGE_LENGTH = 1024
ADDRESS = SOCKET

class RemoteClient(asyncore.dispatcher):

    """Wraps a remote client socket."""
    
    # Server logging mechanism
    log = logging.getLogger('Host')

    def __init__(self, host, socket, address):
        asyncore.dispatcher.__init__(self, socket)
        self.host = host
        self.outbox = collections.deque()

    def say(self, message):
        self.outbox.append(message)

    def handle_read(self):
        client_message = self.recv(MAX_MESSAGE_LENGTH)
        if len(client_message) > 0:
            self.log.info('RemoteClient Received message: %s', client_message)
            self.host.broadcast(client_message)

    def handle_write(self):
        if not self.outbox:
            return
        message = self.outbox.popleft()
        if len(message) > MAX_MESSAGE_LENGTH:
            raise ValueError('Message too long')
        self.send(message)

    def handle_close(self):
        self.log.info("Client left: " + str(self))
        for remote_client in self.host.remote_clients:
            if self == remote_client:
                self.host.remote_clients.remove(self)
            self.close()
            return


class Host(asyncore.dispatcher):

    log = logging.getLogger('Host')

    def __init__(self):
        try:
            os.remove(ADDRESS)
        except OSError:
            pass

        asyncore.dispatcher.__init__(self)
        self.create_socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.set_reuse_addr()
        self.bind(ADDRESS)
        self.listen(1)
        
        self.remote_clients = []

    def handle_accept(self):
        socket, addr = self.accept() # For the remote client.
        self.log.info('Accepted client at %s', addr)
        self.remote_clients.append(RemoteClient(self, socket, addr))

    def handle_read(self):
        message = self.read()
        self.log.info('Host Received message: %s', message)
        #self.broadcast(message)

    def broadcast(self, message):
        self.log.info('Broadcasting message: %s', message)
        for remote_client in self.remote_clients:
            remote_client.say(message)

    def handle_close(self):
        self.close()


def run_server():
    global ADDRESS

    logging.basicConfig(level=logging.INFO)
    logging.info('Creating server at ' + ADDRESS)
    
    host = Host()
    try:
        asyncore.loop()
    finally:
        if(os.path.exists(ADDRESS)):
            os.unlink(ADDRESS)
