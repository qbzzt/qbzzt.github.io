# Building a random number generator for blockchain

The whole point of the blockchain is that *everything* is deterministic.
If you know the state (which is publicly available) and the input, you can calculate the outputs. 
Without that determinism it would be impossible to verify the blockchain's progress, and therefore it won't be decetralized anymore.
This makes it difficult to generate random numbers, which for most use cases cannot be known until they are used.
In this article you learn how to overcome this restrictions to generate random numbers anyway.

**Note:** After [the merge](https://ethereum.org/en/upgrades/merge/) there may be a source of randomness on the EVM itself. 
However, even if that EIP is merged, [the randomness will be far from perfect](https://eips.ethereum.org/EIPS/eip-4399#security-considerations). 


## Why randomness?

In some cases, such as statistical sampling, it is enough to use [pseudorandomness](https://en.wikipedia.org/wiki/Pseudorandomness).
However, there are use cases where a random-seeming number that can be predicted is not good enough.


### NFTs

[Many](https://www.optipunks.com/) [NFT](https://www.optimisticbunnies.com/) [projects](https://optimistic.loogies.io/) randomly assign attributes to their NFTs when they are minted.
As some attributes are more valuable than others, it is necessary for the result of the mint to be unknown to the minter until after the mint.


### Games

Lots of games rely on randomness, either for making decisions or for information that supposed to be hidden from the player.
Without randomness blockchain games would be limited to games such as chess and checkers, where all the information is known to both players.


## Commit/reveal

So, how do we generate random numbers on the blockchain, when *there are no secrets on the blockchain*?
The answer is in the last three words, *on the blockchain*.
To generate random numbers we use a secret number that one side of the interaction has and the other does not, we just make sure that number is **not** on the blockchain.

Here is a protocol that allows two people (or more) to arrive at a mutually agreed random value using a [cryptographic hash](https://en.wikipedia.org/wiki/Cryptographic_hash_function).

1. Side A gets a random number, `randomA`
2. Side A sends a message with the hash of that number `hash(randomA)`.
   This commits side A to the value `randomA`, because while nobody else can guess the value of `randomA`, once side A provides it everybody can check that the value is correct.
3. Side B sends a message with another random number, `randomB`.
4. Side A reveals the value of `randomA` in a third message.
5. Both sides accept that the random nunber is `randomA ^ randomB`, the [exclusive or (xor)](https://en.wikipedia.org/wiki/Exclusive_or) of the two values.
   The advantage of xor here is that every bit is determined equally by both sides, so neither can choose an advantageous "random" value.

This protocol is called commit/reveal. 
[You can read more about it here](https://en.wikipedia.org/wiki/Commitment_scheme#Coin_flipping).


## Betting game

[You can find the Solidity code for a betting game that uses this scheme here](https://github.com/qbzzt/qbzzt.github.io/tree/master/LogRocket/20220615-random).

### Files

There are two "real" files used for the application.
Everything else is just standard [hardhat](https://hardhat.org/) files.

#### Casino.sol

[This file](https://github.com/qbzzt/qbzzt.github.io/blob/master/LogRocket/20220615-random/contracts/Casino.sol) is the actual betting game.
Let's go over it line by line.


```solidity
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
```

Specify the license and Solidity version for this code.

```solidity
contract Casino {
```

Define a contract called `Casino`. 
[Solidity contracts](https://docs.soliditylang.org/en/v0.8.14/structure-of-a-contract.html) are somewhat similar to objects in other languages.

```solidity
  struct ProposedBet {
    address sideA;
    uint value;
    uint placedAt;
    bool accepted;   
  }    // struct ProposedBet
```

This is the [struct](https://docs.soliditylang.org/en/v0.8.14/structure-of-a-contract.html#struct-types) we use to store information about a proposed bet.
It does not include the commitment, the `hash(randomA)` value, because that value is used as the key to locate it.
The fields it does contain are:

| Field | Type | Purpose |
| - | - | - |
| sideA     | [address](https://docs.soliditylang.org/en/v0.8.14/types.html#address) | The address that proposes the bet 
| value     | integer | The size of the bet in [wei](https://ethereum.org/en/glossary/#wei)
| placedAt | integer | The [timestamp](https://en.wikipedia.org/wiki/Unix_time) of the proposal(1).
| accepted | [bool](https://en.wikipedia.org/wiki/Boolean_data_type) | Has the proposal been accepted or not


Notes:

(1) Currently this field is unused, but I explain below why it is useful to keep track of this information.


```solidity
  struct AcceptedBet {
    address sideB;
    uint acceptedAt;
    uint randomB;
  }   // struct AcceptedBet
```

This structure stores the extra information after the bet is accepted.
The only interesting difference is that userB provides us with `randomB` directly, rather than a hash.


```solidity
  // Proposed bets, keyed by the commitment value
  mapping(uint => ProposedBet) public proposedBet;

  // Accepted bets, also keyed by commitment value
  mapping(uint => AcceptedBet) public acceptedBet;
```

These are the [mappings](https://docs.soliditylang.org/en/v0.8.14/types.html#mapping-types) that store the proposed and accepted bets. 


```solidity
  event BetProposed (
    uint indexed _commitment,
    uint value
  );
```

[Events](https://docs.soliditylang.org/en/v0.8.14/abi-spec.html#events) are the standard mechanism used in Ethereum for smart contracts to send messages to the outside world.

This event tells that world that a user (whom we'll name sideA) is proposing a bet and for how much.


```solidity
  event BetAccepted (
    uint indexed _commitment,
    address indexed _sideA
  );
```

This event tells the world (specifically sideA, the one who proposed the bet to begin with, but there is no way to send a message just to a specific user) that it's time to reveal `randomA`.


```solidity
  event BetSettled (
    uint indexed _commitment,
    address winner,
    address loser,
    uint value    
  );
```

This event is emitted when the bet is settled, one way or another.


```solidity
  // Called by sideA to start the process
  function proposeBet(uint _commitment) external payable {
```

The commitment is the sole parameter to this function.
Everything else (the value of the bet and the identity of sideA) is available as part of the transaction.

Notice that this function is [`payable`](https://mirror.xyz/0x9ae1e982Fc9A9D799e611843CB9154410f11Fe35/oLf7vEBkRn3ESSOqumpaWSVPJeWaBAb04SNMFnpawNA).
This means that it can accept Ether in payment. 


```solidity
    require(proposedBet[_commitment].value == 0,
      "there is already a bet on that commitment");
    require(msg.value > 0,
      "you need to actually bet something");
```

Most externally called functions start with a bunch of [`require`](https://docs.soliditylang.org/en/latest/control-structures.html#error-handling-assert-require-revert-and-exceptions) statements.
When we write a smart contract we *have* to assume that the function will be called maliciously.

In this case we have two conditions:

1. If there is already a bet on the commitment, reject this one.
   Otherwise people might try to use it to overwrite existing bets, which would cause the amount sideA put in to get stuck in the contract forever.

2. If the bet is for 0 wei, reject it.


```solidity
    proposedBet[_commitment].sideA = msg.sender;
    proposedBet[_commitment].value = msg.value;
    proposedBet[_commitment].placedAt = block.timestamp;
    // accepted is false by default
```

If everything is OK, write the information to `proposedBet`. 
Because of the way Ethereum storage works, we don't need to create a new struct, fill it and then assign it to the mapping.
Instead, there is already a struct for every commitment value, filled with zeros.
We just need to modify it.


```solidity
    emit BetProposed(_commitment, msg.value);
  }  // function proposeBet
```

And tell the world about the proposed bet (along with the amount).


```solidity
  // Called by sideB to continue
  function acceptBet(uint _commitment, uint _random) external payable {
```

We need two parameters: the commitment, to know what the user is accepting, and the user's random value.


```solidity
    require(!proposedBet[_commitment].accepted,
      "Bet has already been accepted");
    require(proposedBet[_commitment].sideA != address(0),
      "Nobody made that bet");
    require(msg.value == proposedBet[_commitment].value,
      "Need to bet the same amount as sideA");
```

Here we have three ways in which the bet acceptance can be a problem:

1. If the bet has already been accepted by somebody, it cannot be accepted again.
2. If the sideA address is zero, it means that nobody made that bet to begin with.
3. Obviously, sideB needs to bet the same amount as sideA.


```solidity
    acceptedBet[_commitment].sideB = msg.sender;
    acceptedBet[_commitment].acceptedAt = block.timestamp;
    acceptedBet[_commitment].randomB = _random;
    proposedBet[_commitment].accepted = true;

    emit BetAccepted(_commitment, proposedBet[_commitment].sideA);
  }   // function acceptBet

```

If all the requirements have been met, create the new `AcceptedBet`, mark in the proposed bet that it had been accepted, and then emit the message.



```solidity
  // Called by sideA to reveal their random value and conclude the bet
  function reveal(uint _random) external {
```

This function is the great reveal. SideA reveals `randomA`, and we can see who won.

```solidity
    uint _commitment = uint256(keccak256(abi.encodePacked(_random)));
```

We don't need the commitment itself as a parameter, because we can derive it from `randomA`. 

```solidity
    address payable _sideA = payable(msg.sender);
    address payable _sideB = payable(acceptedBet[_commitment].sideB);
```

To reduce the risk of accidentally sending ETH to addresses where it will get stuck, Solidity only lets you send it to addresses of type [`address payable`](https://docs.soliditylang.org/en/latest/types.html#address).


```solidity
    uint _agreedRandom = _random ^ acceptedBet[_commitment].randomB;
```

The agreed random value is a xor of the two random values as explained above.


```solidity
    uint _value = proposedBet[_commitment].value;
```

It's just easier to refer to `_value` instead of `proposedBet[_commitment].value`.


```solidity
    require(proposedBet[_commitment].sideA == msg.sender,
      "Not a bet you placed or wrong value");
    require(proposedBet[_commitment].accepted,
      "Bet has not been accepted yet");
```

1. There could be two reasons that `proposedBet[_commitment].sideA == msg.sender` isn't equal to the commitment.
   Either the user did not place the bet, or the value provided as `_random` is wrong (in that case `_commitment` will be a different value and therefore the proposed bet in that location won't have the right sideA).
2. This function only makes sense after the bet has been accepted.   


```solidity
    // Pay and emit an event
    if (_agreedRandom % 2 == 0) {
```

Use the least significant bit of the value to decide the winner.


```solidity
      // sideA wins
      _sideA.transfer(2*_value);
      emit BetSettled(_commitment, _sideA, _sideB, _value);
    } else {
      // sideB wins
      _sideB.transfer(2*_value);
      emit BetSettled(_commitment, _sideB, _sideA, _value);      
    }
```

Give the winner the bet, and emit a message to tell the world the bet has been settled.


```solidity
    // Cleanup
    delete proposedBet[_commitment];
    delete acceptedBet[_commitment];
```

Delete the bet storage, which is no longer needed. 
This is *not* to allow somebody else to bet on the same commitment, because anybody can look back in the blockchain and see what the commitment was and the value revealed for it.
Instead, the purpose of deleting this data is to collect the gas refund for clearning no longer needed storage.

```solidity
  }  // function reveal


}   // contract Casino
```


End of the function and contract.


##### Note on optimization

These days the cheapest way to transact on Ethereum is to [use a rollup](https://ethereum.org/en/layer-2/). 
Basically, that's a blockchain that writes all transactions to Ethereum (so anybody can verify the blockchain state, because Ethereum is uncensorable), but runs the processing somewhere else where it is cheaper. 
The state root is then posted to L1, and there are guarantees (either [mathematical](https://ethereum.org/en/developers/docs/scaling/zk-rollups/) or [economical](https://ethereum.org/en/developers/docs/scaling/optimistic-rollups/)) that it is the correct value. 
[Using this state root it is possible to prove any part of the state, for example that somebody owns something](https://medium.com/crypto-0-nite/merkle-proofs-explained-6dd429623dc5).

This mechanism means that processing (which can be done on the rollup, a.k.a. layer 2 or L2) is very cheap, and in comparison transaction data (which has to be stored on Ethereum, a.k.a. layer 1 or L1) is very expensive. 
As I'm writing this, [in the rollup I use](https://www.optimism.io/), L1 gas is 20,000 times the cost of L2 gas. 
[Click here to see the current ratio](https://public-grafana.optimism.io/d/9hkhMxn7z/public-dashboard?orgId=1&refresh=5m).

For this reason `reveal` only takes `randomA`.
I could have written it to also get the value of the commitment, and then it could distinguish between wrong values and bets that don't exist (or haven't been placed by the sender). 
However, on a rollup that would significantly increase the cost of the transaction, so it is not worth doing.


#### casino-test.js

This is the JavaScript code that tests `Casino`.
It is repetitive, so I'll only explain the interesting parts.

```js
const valA = ethers.utils.keccak256(0xBAD060A7)
```

The hash function on the ethers package [`ethers.utils.keccak256`](https://docs.ethers.io/v5/api/utils/hashing/#utils-keccak256) accepts a string that contains a hexadecimal number.
That number is not converted to 256 bits if it is smaller, so for example `0x01`, `0x0001`, and `0x000001` hash to different values.
To create a hash that could be identical to the one produced on Solidity, we would need a 64 character number, even if it is `0x00..00`.
Using the hash function here is a simple way to make sure the value we generate is 32 bytes.

```js
const hashA = ethers.utils.keccak256(valA)
const valBwin = ethers.utils.keccak256(0x600D60A7)
const valBlose = ethers.utils.keccak256(0xBAD060A7)
```

We want to check both possible results: A win and B win. 
If the value sideB sends is the same as the one hashed by sideA, the result is zero (any number xor itself is zero), and therefore B loses.


```js
// Chai's expect(<operation>).to.be.revertedWith behaves
// strangely, so I'm implementing that functionality myself
// with try/catch
const interpretErr = err => {
  if (err.reason)
    return err.reason
  else
    return err.stackTrace[0].message.value.toString('ascii')
}
```

When using the Hardhat EVM for local testing the revert reason is provided a [`Buffer`](https://nodejs.org/api/buffer.html) object inside the stack trace.
When connecting to an actual blockchain we get it in the `reason` field.
This function lets us ignore this difference in the rest of the code.

```js
describe("Casino", async () => {
  it("Not allow you to propose a zero wei bet", async () => {
```

This is the standard way to use [the Chai testing library](https://www.chaijs.com/). You `describe` a piece of code with a number of `it("things that should happen")` statements.


```js
    f = await ethers.getContractFactory("Casino")
    c = await f.deploy()
```

[This is the standard Ethers mechanism to create a new instance of a contract](https://docs.ethers.io/v5/api/contract/contract-factory/#ContractFactory--creating).

```js

    try {
      tx = await c.proposeBet(hashA)
```

By default transactions have a `value` (amount of attached wei) of zero.


```js
      rcpt = await tx.wait()
```

The function call `tx.wait()` returns a [`Promise`](https://www.w3schools.com/js/js_promise.asp) object.
The expression [`await <Promise>`](https://www.w3schools.com/js/js_async.asp) pauses until the promise is resolved, and then either continues (if the promise is resolved successfully) or throws an error (if the promise ends with an error).


```js
      // If we get here, it's a fail
      expect("this").to.equal("fail")
```

If there is no error it means that a zero wei bet was accepted.
This means the code failed the test.

```js
    } catch(err) {
      expect(interpretErr(err)).to
        .match(/you need to actually bet something/)        
    }
  })   // it "Not allow you to bet zero wei"
```

Here we catch the error, and verify that the error matches the one we'd expect from the `Casino` contract.
If we run using the Hardhat EVM the Buffer we get back includes some other characters, so it's easiest to just `match` to make sure we see the error string rather than check for equality.

```js
  it("Not allow you to accept a bet that doesn't exist", async () => {
    .
    .
    .
  })   // it "Not allow you to accept a bet that doesn't exist" 
```

The other error conditions, such as this one, are pretty similar.

```js
  it("Allow you to propose and accept bets", async () => {
    f = await ethers.getContractFactory("Casino")
    c = await f.deploy()

    tx = await c.proposeBet(hashA, {value: 10})
```

To change the default behavior of contract interaction, for example to attach a payment to the transaction, [we add an override hash as an extra parameter](https://docs.ethers.io/v5/api/contract/contract/#Contract-functionsCall). 

In this case, we send 10 wei to test that that kind of bet is accepted.

```js
    rcpt = await tx.wait()
    expect(rcpt.events[0].event).to.equal("BetProposed")
```

If a transaction is successful, we get the receipt when the promise of `tx.wait()` is resolved.
Among other things, that receipt has all the emitted events.
In this case we expect to have one event, the `BetProposed` one.

**Note:** In production level code we'd also check that the parameters emitted are correct.

```js
    tx = await c.acceptBet(hashA, valBwin, {value: 10})
    rcpt = await tx.wait()
    expect(rcpt.events[0].event).to.equal("BetAccepted")      
  })   // it "Allow you to accept a bet"


  it("Not allow you to accept an already accepted bet", async () => {
    f = await ethers.getContractFactory("Casino")
    c = await f.deploy()

    tx = await c.proposeBet(hashA, {value: 10})
    rcpt = await tx.wait()
    expect(rcpt.events[0].event).to.equal("BetProposed")
    tx = await c.acceptBet(hashA, valBwin, {value: 10})
    rcpt = await tx.wait()
    expect(rcpt.events[0].event).to.equal("BetAccepted")
```

Sometimes we need to have a few successful operations to get to the failure we want to test.

```js
    try {
      tx = await c.acceptBet(hashA, valBwin, {value: 10})
      rcpt = await tx.wait()   
      expect("this").to.equal("fail")      
    } catch (err) {
        expect(interpretErr(err)).to
          .match(/Bet has already been accepted/)
    }          
  })   // it "Not allow you to accept an already accepted bet" 
```

Such as an attempt to double-accept a bet.

```
  it("Not allow you to accept with the wrong amount", async () => {
      .
      .
      .
  })   // it "Not allow you to accept with the wrong amount"   


  it("Not allow you to reveal with wrong value", async () => {
      .
      .
      .
  })   // it "Not allow you to accept an already accepted bet" 


  it("Not allow you to reveal before bet is accepted", async () => {
      .
      .
      .
  })   // it "Not allow you to reveal before bet is accepted"  
```

Note that while the transaction would revert in this case, it will still stay on the blockchain.
This means that if sideA reveals prematurely, anybody else can accept the bet with a winning value.


```js
  it("Work all the way through (B wins)", async () => {
    signer = await ethers.getSigners()
    f = await ethers.getContractFactory("Casino")
    cA = await f.deploy()
    cB = cA.connect(signer[1])
```

So far we've used a single address for everything.
However, to check a bet between two users we need to have two users.
We use [`ethers.getSigners()`](https://hardhat.org/guides/waffle-testing.html#setting-up) to get an array of signers (all addresses derived from the same mnemonic). When we use [the `connect` method](https://docs.ethers.io/v5/api/contract/contract/#Contract-connect) to get a contract object that goes through one of those signers.


```js
    .
    .
    .
    // A sends the transaction, so the change due to the
    // bet will only be clearly visible in B

    preBalanceB = await ethers.provider.getBalance(signer[1].address)    
```

In this system Ether is used both as the asset being gambled, and the currency used to pay for transactions.
As a result, the change in sideA's balance will be partially the result of paying for the `reveal` transaction.
To see how the balance changed because of the bet, we look at sideB.

```js
    tx = await cA.reveal(valA)
    rcpt = await tx.wait()
    expect(rcpt.events[0].event).to.equal("BetSettled")
    postBalanceB = await ethers.provider.getBalance(signer[1].address)        
    deltaB = postBalanceB.sub(preBalanceB)
    expect(deltaB.toNumber()).to.equal(2e10)   


  })   // it "Work all the way through (B wins)"


  it("Work all the way through (A wins)", async () => {
      .
      .
      .
      .
    expect(deltaB.toNumber()).to.equal(0) 
  })   // it "Work all the way through (A wins)"


})     // describe("Casino")

```



### Abuse and preventing it

When you write a smart contract you should think about hostile users and how they can abuse it.
Here are a few ways to abuse the `Casino` contract.

#### Never reveal

There is nothing obligating sideA to reveal the random number, ever. 
A losing sideA can't get anything back, but a spiteful sideA can avoid issuing the `reveal` transaction and therefore prevent sideB from collecting either.

This problem has an easy solution.
Keep a timstamp of when sideB accepted the bet.
If a predefined length of time has passed since the timestamp, and sideA has not responded with a valid `reveal`, let sideB issue a `forefeit` transaction and get the bet anyway.


#### Frontrunning

Ethereum transactions don't get executed immediately.
Instead, they are placed into an entity called the memepool, and miners (or after the merge block proposers) get to choose which transactions to put in the block they submit. 
Typically, those transactions that agree to pay the most gas, and therefore provide the most profit, are the ones chosen.

As soon as the sideA sees sideB's `acceptBet` transaction in the mempool, with a random value that would cause sideA to lose, sideA can issue a different `acceptBet` transaction (possibly from a different address). 
If sideA's `acceptBet` transaction gives the miner more gas, we can expect the miner to play it a block first.
This way sideA can withdraw from a bet instead of losing it.

This strategy is called [frontrunning](https://consensys.github.io/smart-contract-best-practices/attacks/frontrunning/).
Unfortunately, the decentralized structure of Ethereum makes it impossible to prevent.
The mempool has to be available, at least for miners (and stakers after the merge), for the network to be uncensorable.

This issue stems from the information asymmetry between sideA and sideB after sideB submits the `acceptBet` transaction.
At that point sideA already knows `randomA` and `randomB`, and can therefore see who won. 
However, sideB has no idea until the `reveal`.
We can remove the frontrunning by removing the asymmetry.
If in `acceptBet` sideB only discloses `hash(randomB)`, sideA doesn't know who won either, making it useless to frontrun the transaction.
Then, once sideB's acceptance of the bet is part of the blockchain, both sideA and sideB can issue `reveal` transactions.
Once one of the sides issues `reveal` the other side knows who won, but if we add `forefeit` transactions there is no advantage to removing to reveal beyond the small charge for the transaction itself.


## Conclusion

Creating random numbers on a deterministic machine is not trivial, but by offloading the task to the users we managed to achieve a pretty good solution. 
As long as the two sides have an interest in the result being random, we can be assured it would be.
 