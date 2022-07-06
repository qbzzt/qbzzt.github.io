const { expect } = require("chai")



const data2Str = str => String.fromCharCode(...str.split(/([0-9a-f]{2})/).
    filter(x => x).map(x => '0x'+x).filter(x => x != '0x00')).slice(7)

const getMsgs = async (chirper, sender) => {
  blockList = (await chirper.getSenderMessages(sender)).map(x => x.toNumber())
  
  blocks = await Promise.all(
    blockList.map(async x => await ethers.provider.getBlockWithTransactions(x))
  )

  // Get the timestamps
  timestamps = {}
  blocks.map(block => timestamps[block.number] = block.timestamp)

  // Get the texts
  allTxs = blocks.map(x => x.transactions).flat()
  ourTxs = allTxs.filter(x => x.from == sender && x.to == chirper.address)
  msgs = ourTxs.map(x => {return {
    text: data2Str(x.data),
    time: timestamps[x.blockNumber]
  }})

  return msgs
}   // getMsgs


describe("Chirper",  async () => {
  it("Should return messages posted by a user", async () => {
    messages = ["Hello, world", "Shalom Olam", "Salut Mundi"]

    Chirper = await ethers.getContractFactory("Chirper")
    chirper = await Chirper.deploy()

    messages.map(async msg => {
      tx = await chirper.post(msg)
      rcpt = await tx.wait()
    })

    fromAddr = (await ethers.getSigners())[0].address
    receivedMessages = await getMsgs(chirper, fromAddr)

    messages.map((msg,i) => expect(msg).to.equal(receivedMessages[i].text))
    
  })   // it should return messages posted ...

  it("Should ignore irrelevant messages", async () => {  
    Chirper = await ethers.getContractFactory("Chirper")
    chirper1 = await Chirper.deploy()
    otherWallet = (await ethers.getSigners())[1]
    chirper1a = chirper1.connect(otherWallet)    
    chirper2 = await Chirper.deploy()

    chirper1.post("Hello, world")
    chirper2.post("Not relevant") // Different chirper instance
    chirper1a.post("Hello, world, from somebody else") // Same chirper, different source address
    chirper1.post("Hello, world, 2nd half")
    chirper2.post("Not relevant, 2nd half")  // Different chirper instance
    chirper1a.post("Hello, world, from somebody else") // Same chirper, different source address    

    fromAddr = (await ethers.getSigners())[0].address
    receivedMessages = await getMsgs(chirper1, fromAddr)
    expected = ["Hello, world", "Hello, world, 2nd half"]
    expected.map((msg,i) => expect(msg).to.equal(receivedMessages[i].text))    
  })   // it should ignore irrelevant messages


}) //describe Chirper
