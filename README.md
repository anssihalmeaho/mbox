# mbox
Messaging library for sending and receiving **messages** to/from other fibers.
Messages are delivered via **Message Boxes** (or "mail boxes" in Actor model terminology).

## Concepts
**Message Box** queue for asynchronoulsy writing/reading data by (FunL) fibers.
**Message Box** has unique identity (id, in practise it's UUID).
Client can also give name for certain **Message Box**.

## Model
Model is hybrid from **Communicating Sequential Processes (CSP) model** and from **Actor model**.
**Message Boxes** are queues and writing or reading doesn't block caller there (unlike in **CSP model**).
But unlike in **Actor model** where "process" has only one "mailbox", **Message Box** and fibers
are loosely coupled with each other. One fiber can receive from many Message Boxes and many fibers
can receive from one Message Box.

## Local/Global messaging

## Naming service

## Install


## Creating mbox instance: mbox.new

## mbox object methods

### 'create-mbox'

### 'sendmsg'

### 'recmsg'

### 'register-with-name'

### 'id-by-name'

### 'contents'

### 'all-names'


## Command line chat example

## Protocol (peer communication)

## Future development issues
