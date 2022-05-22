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
The only interesting difference is that userB provides us with `randomB` directly, so there is no need to store a hash instead.


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

This event tells that world that a user (whom we'll name `sideA`) is proposing a bet and for how much.


```solidity
  event BetAccepted (
    uint indexed _commitment,
    address indexed _sideA
  );
```

This event tells the world (specifically `sideA`, the one who proposed the bet to begin with, but there is no way to send a message just to a specific user) that it's time to reveal `randomA`.


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


```solidity
    require(!proposedBet[_commitment].accepted,
      "Bet has already been accepted");
    require(proposedBet[_commitment].sideA != address(0),
      "Nobody made that bet");
    require(msg.value == proposedBet[_commitment].value,
      "Need to bet the same amount as sideA");

    acceptedBet[_commitment].sideB = msg.sender;
    acceptedBet[_commitment].acceptedAt = block.timestamp;
    acceptedBet[_commitment].randomB = _random;
    proposedBet[_commitment].accepted = true;

    emit BetAccepted(_commitment, proposedBet[_commitment].sideA);
  }   // function acceptBet


  // Called by sideA to reveal their random value and conclude the bet
  function reveal(uint _random) external {
    uint _commitment = uint256(keccak256(abi.encodePacked(_random)));
    address payable _sideA = payable(msg.sender);
    address payable _sideB = payable(acceptedBet[_commitment].sideB);
    uint _agreedRandom = _random ^ acceptedBet[_commitment].randomB;
    uint _value = proposedBet[_commitment].value;

    require(proposedBet[_commitment].sideA == msg.sender,
      "Not a bet you placed or wrong value");
    require(proposedBet[_commitment].accepted,
      "Bet has not been accepted yet");

    // Pay and emit an event
    if (_agreedRandom % 2 == 0) {
      // sideA wins
      _sideA.transfer(2*_value);
      emit BetSettled(_commitment, _sideA, _sideB, _value);
    } else {
      // sideB wins
      _sideB.transfer(2*_value);
      emit BetSettled(_commitment, _sideB, _sideA, _value);      
    }

    // Cleanup
    delete proposedBet[_commitment];
    delete acceptedBet[_commitment];

  }  // function reveal

}   // contract Casino
```


##### Notes on optimization


#### casino-test.js


### Abuse and preventing it

#### Never reveal

#### Frontrunning



## Conclusion

