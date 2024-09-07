# Game server message broker

A broker is made up of one supervisor (Mppm.Broker.Supervisor) and two GenServers:
- Mppm.Broker.ReceiverServer
- Mppm.Broker.RequesterServer

The Supervisor is started after game server launch, once the XMLRPC port is detected. The
ReceiverServer then opens the connection and provides a call method so that the
RequesterServer can retrieve the open port. Everything's stopped on server shutdown.

This design choice has been made to allow either the receiving or requesting part
of the broker to be able to independently fail without impeding its counterpart.

References of the XML/RPC methods and callbacks can be found
<a href="https://doc.maniaplanet.com/dedicated-server/references/xml-rpc-methods">
here.</a>
