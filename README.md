# mbox
Messaging library for sending and receiving **messages** to/from other fibers.
Library is for [FunL programs](https://github.com/anssihalmeaho/funl) to use.
Messages are delivered via **Message Boxes** (or "mail boxes" in Actor model terminology).

## Concepts
**Message Box** queue for asynchronoulsy writing/reading data by (FunL) fibers.
**Message Box** has unique identity (id, in practise it's UUID).
Client can also give name for certain **Message Box**.

Message Box is bounded buffer (it has maximum size). Writing to message box is not
synchronized to reader access. If message box s full then writing to it discards message.

## Model
Model is hybrid from **Communicating Sequential Processes (CSP) model** and from **Actor model**.
**Message Boxes** are queues and writing or reading doesn't block caller there (unlike in **CSP model**).
But unlike in **Actor model** where "process" has only one "mailbox", **Message Box** and fibers
are loosely coupled with each other. One fiber can receive from many Message Boxes and many fibers
can receive from one Message Box.

## Local/Global messaging
Message Boxes can be used in local communication (fibers using same mbox instance to send and receive messages)
or it can be used globally so that message boxes are shared between several mbox instances.

Those mbox instances can be also in separate processes (FunL interpreters) or even in separate machines.
Peer instances are connected all to each other and all message boxes and names are shared (distributed) between instances (full mesh).
Under the hood **stdrpc** is used for communication between peer instances.

## Naming service
Client can give name for Message Box. Names are shared between mbox instances.
Client can ask message box by its name.
It's clients responsibility to take care if names need to be unique.

## Install
Prerequisite is to have [FunL interpreter](https://github.com/anssihalmeaho/funl) compiled.

Fetch repository with --recursive option (so that needed fuse submodule is included):

```
git clone --recursive https://github.com/anssihalmeaho/mbox.git
```

## Creating mbox instance: mbox.new
New mbox instance (object/map) is created with **mbox.new** call:

```
call(mbox.new own-name own-address list-of-peers) -> <mbox-instance/map>
```

Arguments are:

1. mbox instance own name
2. mbox instance own address (IP:port)
3. list of peer addresses

Return value is mbox instance (object/map).

## mbox object methods
mbox instance object (map) contains methods for client to use (map: string -> procedure).

### 'create-mbox'
Creates new Message Box.
Maximum size is given as argument (_int_).

```
call(create-mbox max-size) -> list(ok error mbox-id)
```

Return value is list:

1. _bool_: **true** if success, **false** otherwise
2. _string_: error description if failure, '' if success
3. message box id (_string_)

### 'sendmsg'
Sends message (value, 2nd argument) to given message box (message box id, string).

```
call(sendmsg mbox-id message-value) -> list(ok error)
```

Return value is list:

1. **true** if success, **false** otherwise
2. error description if failure, '' if success

### 'recmsg'
Receives message (value) from given message box.

```
call(recmsg mbox-id) -> list(ok message-value)
```

Return value is list:

1. **true** if message was received, **false** otherwise
2. received value

### 'register-with-name'
Assigns name (2nd argument, string) for message box (1st argument).

```
call(register-with-name mbox-id mbox-name) -> true
```

### 'id-by-name'
Returns message box (mbox id) for given name.

```
call(id-by-name mbox-name) -> list(found mbox-id)
```

Return value is list:

1. **true** if name was found, **false** otherwise
2. related message box id (string)

### 'contents'
Returns whole state of message box instance.
Only meant for debugging purposes.

```
call(contents) -> value
```

### 'all-names'
Returns all message box names (as list fo strings)

```
call(all-names) -> list(name/string name/string ...)
```

## Command line chat example
Example code can be found in [/examples](https://github.com/anssihalmeaho/mbox/tree/main/examples).

Example has 3 chat clients which communicate with each other.
Start those each separately:

```
funla examples/a-chat.fnl
press exit or quit to quit to exit from client
clientA>
```

```
funla examples/b-chat.fnl
press exit or quit to quit to exit from client
clientB>
```

```
funla examples/c-chat.fnl
press exit or quit to quit to exit from client
clientC>
```

Write for example from clientA something and it's received/printed by others:

```
clientA> Hello, it's A here !
clientA>
```

```
clientB>
 -> Hello, it's A here !
```

```
clientC>
 -> Hello, it's A here !
```

## Implementation
Implementation of message box library is in **mbox.fnl** module.
It uses another module (**mbpeers.fnl**) for accessing data about
anything that is in peer instances.

Peer data object is created in **mbpeers** with **new** procedure.
That object (map) is kind of **aggregate** as it encapsulates
consistent and composite view to peer instance data.

## Protocol (peer communication)
Protocol between peer instances contains several operations.
Oerations are request/reply pairs done via RPC calls.

### Joining with other peers: 'join'
In startup mbox instance makes **'join'** call to each peer.

Request:

```
list('join' own-name own-id peer-address)
```

Reply:

```
list(peer-id peer-name peer-address peer-local-mbox-ids peer-known-names)
```

### Registering new message box to peers: 'reg'
When new message box is created it's informed to peers.

Request:

```
list('reg' own-id new-mbox-id)
```

Reply:

```
'ok'
```

### Adding new name for message box: 'name'
Informing peers about new name -> message box binding.

Request:

```
list('name' own-id mbox-name mbox-id)
```

Reply:

```
true
```

### Sending message to peer: 'send'
Message is sent to peer instance message box.

Request:

```
list('send' own-id mbox-id message-value)
```

Reply:

```
list(is-success error-description)
```

## Future development issues
Things to do in future maybe:

* working only in local mode (?)
* handling writing to full message box (return value could tell if writing failed)
* reactive interface for name/mbox changes (**evenz** -like perhaps)
* separate "pending peers" -list & periodic retrys to connect
* gossip based membership for peers
* routing topology (not only full mesh)
* failure/recovery handling of peer instance
* unregistrations/release mbox/shutdown
* uuid generation => some **FunL** standard library maybe
* security/TLS/authentication
* **rpc** (remote procedure call) on top of mbox ?
