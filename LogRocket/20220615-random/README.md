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



```solidity
contract Casino {

  struct ProposedBet {
    address sideA;
    uint value;
    uint placedAt;
    bool accepted;   
  }    // struct ProposedBet


  struct AcceptedBet {
    address sideB;
    uint acceptedAt;
    uint randomB;
  }   // struct AcceptedBet

  // Proposed bets, keyed by the commitment value
  mapping(uint => ProposedBet) public proposedBet;

  // Accepted bets, also keyed by commitment value
  mapping(uint => AcceptedBet) public acceptedBet;

  event BetProposed (
    uint indexed _commitment,
    uint value
  );

  event BetAccepted (
    uint indexed _commitment,
    address indexed _sideA
  );


  event BetSettled (
    uint indexed _commitment,
    address winner,
    address loser,
    uint value    
  );


  // Called by sideA to start the process
  function proposeBet(uint _commitment) external payable {
    require(proposedBet[_commitment].value == 0,
      "there is already a bet on that commitment");
    require(msg.value > 0,
      "you need to actually bet something");

    proposedBet[_commitment].sideA = msg.sender;
    proposedBet[_commitment].value = msg.value;
    proposedBet[_commitment].placedAt = block.timestamp;
    // accepted is false by default

    emit BetProposed(_commitment, msg.value);
  }  // function proposeBet


  // Called by sideB to continue
  function acceptBet(uint _commitment, uint _random) external payable {

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

#### casino-test.js


### Abuse and preventing it

#### Never reveal

#### Frontrunning



## Conclusion

