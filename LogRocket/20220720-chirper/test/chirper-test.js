// The API

const data2Str = str => {
  bytes = str.match(/[0-9a-f]{2}/g)
  usefulBytes = bytes.filter(x => x != "00")
  hexBytes = usefulBytes.map(x => '0x' + x)
  decodedStr = String.fromCharCode(...hexBytes)
  result = decodedStr.slice(6)
  return result
}  // data2Str

const getMsgs = async (chirper, sender) => {
  blockList = (await chirper.getSenderMessages(sender)).map(x => x.toNumber())

  blocks = await Promise.all(
    blockList.map(x => ethers.provider.getBlockWithTransactions(x))
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


const post = async (chirper, msg) => {
  await (await chirper.post(msg)).wait()
}    // post



// The testing code

const { expect } = require("chai")

describe("Chirper",  async () => {
  it("Should return messages posted by a user", async () => {
    messages = ["Hello, world", "Shalom Olam", "Salut Mundi"]

    Chirper = await ethers.getContractFactory("Chirper")
    chirper = await Chirper.deploy()

    for(var i=0; i<messages.length; i++)
      await post(chirper, messages[i])

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

    await post(chirper1, "Hello, world")

    // Different chirper instance
    await post(chirper2, "Not relevant")

    // Same chirper, different source address
    await post(chirper1a, "Hello, world, from somebody else")

    await post(chirper1, "Hello, world, 2nd half")
    await post(chirper2, "Also not relevant (different chirper)")
    await post(chirper1a, "Same chirper, different user, also irrelevant")
    
    receivedMessages = await getMsgs(chirper1, 
        (await ethers.getSigners())[0].address)
    expected = ["Hello, world", "Hello, world, 2nd half"]
    expected.map((msg,i) => expect(msg).to.equal(receivedMessages[i].text))     
  })   // it should ignore irrelevant messages


}) //describe Chirper
