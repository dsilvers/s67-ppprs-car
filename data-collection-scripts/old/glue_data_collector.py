#!/usr/bin/python

from glue.client import Client, start_client

class Writer(Client):
    name = "writer"
    purpose = "writer"



start_client()
