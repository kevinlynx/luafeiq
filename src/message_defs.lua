--[[
  Message type definitions
  Kevin Lynx
  1.26.2011
  Prototype document:
  .When get online, broadcast 0 and 01H(with nickname and group name) messages.
  .Others will send 03H(same as 01H) response to you.
  .If you receive 01H, send 03H to the sender.
  .Multicast C9H to become a memeber of a group and later you can talk in the 
   group free.
  .Send private message process:
   When you get online, mark ENCRYPT option 0, and the message will not be encrypted,
   1.Send message(20H) to dest
   2.Dest send response(21H) with a message number in the message sent from src.
   3.Src will check the message number response from dest to be sure the message
     arrived.
--]]

MSG_NOOP = 0x0000
MSG_BR_ENTRY = 0x0001
MSG_BR_EXIT = 0x0002
MSG_BR_ENTRYANS = 0x0003
MSG_SEND_GROUP = 0x0023
MSG_BR_GROUPENTRY = 0x00C9
MSG_SEND_MSG = 0x0020
MSG_RECV_MSG = 0x0021

OPT_ABSENCE = 0x100
OPT_ENCRYPT = 0x400000
OPT_FILEATTACH = 0x200000

MASK_CMD = 0x000000ff
MASK_OPT = 0xffffff00

function msg_get_cmd(t)
    return pickmask(t, MASK_CMD)
end

function msg_get_opt(t)
    return pickmask(t, MASK_OPT)
end
