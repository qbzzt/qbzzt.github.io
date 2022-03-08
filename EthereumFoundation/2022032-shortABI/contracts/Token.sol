//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


// An ERC-20 token for testing purposes
// Based on the OpenZeppelin ERC-20 contract, but with a faucet function

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";




contract OrisUselessToken is ERC20 {

    /**
     * @dev Calls the ERC20 constructor. 
     */
    constructor(
    ) ERC20("Oris useless token", "OUT") {
    }

    /**
     * @dev Gives the caller 1000 tokens to play with
     */
    function faucet() external {
        _mint(msg.sender, 1000);
    }   // function faucet

    /**
     * @dev Returns the number of decimals used to get its user representation.
     */
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }   // function decimals

}       // contract OrisUselessToken