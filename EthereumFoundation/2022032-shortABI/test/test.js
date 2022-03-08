const { expect } = require("chai");

describe("CalldataInterpreter", function () {
  it("Should let us use tokens", async function () {
    const Token = await ethers.getContractFactory("OrisUselessToken")
    const token = await Token.deploy()
    await token.deployed()
    console.log("Token addr:", token.address)
    
    const Cdi = await ethers.getContractFactory("CalldataInterpreter")
    const cdi = await Cdi.deploy(token.address)
    await cdi.deployed()
    console.log("CalldataInterpreter addr:", cdi.address)

    const signer = await ethers.getSigner()

    // Get tokens to play with
    const faucetTx = {
      to: cdi.address,
      data: "0x01"
    }
    await (await signer.sendTransaction(faucetTx)).wait()

    // Check the faucet provides the tokens correctly
    expect (await token.balanceOf(signer.address)).to.equal(1000)

    // Give the CDI an allowance (approvals cannot be proxied)
    const approveTX = await token.approve(cdi.address, 10000)
    await approveTX.wait()
    expect (await token.allowance(signer.address, cdi.address))
      .to.equal(10000)
      
    // Transfer tokens
    const destAddr = "0xf5a6ead936fb47f342bb63e676479bddf26ebe1d"
    const transferTx = {
      to: cdi.address,
      data: "0x02" + destAddr.slice(2,42) + "0100"
    }
    await (await signer.sendTransaction(transferTx)).wait()

    // Check that we have 256 tokens less
    expect (await token.balanceOf(signer.address)).to.equal(1000-256)    

    // And that our destination got them
    expect (await token.balanceOf(destAddr)).to.equal(256)        
  })    // it
})      // describe