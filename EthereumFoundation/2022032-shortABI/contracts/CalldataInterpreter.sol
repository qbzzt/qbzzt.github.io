//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


import { OrisUselessToken } from "./Token.sol";

contract CalldataInterpreter {

    OrisUselessToken public immutable token;
    
    /**
     * @dev Specify the token address
     * @param tokenAddr_ ERC-20 contract address
     */
    constructor(
        address tokenAddr_
    )  {
        token = OrisUselessToken(tokenAddr_);
    }   // constructor


    function calldataVal(uint startByte, uint length)
        private pure returns (uint) {
        uint _calldatasize;
        uint _retVal;

        assembly {
            _calldatasize := calldatasize()
        }

        require(length < 0x21, 
            "calldataVal length limit is 32 bytes");

        require(length + startByte <= _calldatasize,
            "calldataVal trying to read beyond calldatasize");

        assembly {
            _retVal := calldataload(startByte)
        }

        _retVal = _retVal >> (256-length*8);

        return _retVal;
    }

    fallback() external {
        uint _func;

        _func = calldataVal(0, 1);

        // Call the state changing methods of token using
        // information from the calldata

        // faucet
        if (_func == 1) {
            token.faucet();
            token.transfer(msg.sender,
                token.balanceOf(address(this)));
        }

        // transfer (assume we have an allowance for it)
        if (_func == 2) {
            token.transferFrom(
                msg.sender,
                address(uint160(calldataVal(1, 20))),
                calldataVal(21, 2)
            );
        }
    }   // fallback

}       // contract CalldataInterpreter