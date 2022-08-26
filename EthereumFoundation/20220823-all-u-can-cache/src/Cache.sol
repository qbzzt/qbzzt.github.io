// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


contract Cache {

    bytes1 public constant INTO_CACHE = 0xFF;
    bytes1 public constant DONT_CACHE = 0xFE;

    mapping(uint => uint) public val2key;

    // Location n has the value for key n+1, because we need to preserve
    // zero as "not in the cache".
    uint[] public key2val;

    function cacheRead(uint _key) public view returns (uint) {
        require(_key <= key2val.length, "Reading uninitialize cache entry");
        return key2val[_key-1];
    }  // cacheRead

    // Write a value to the cache if it's not there already
    // Only public to enable the test to work
    function cacheWrite(uint _value) public returns (uint) {
        // If the value is already in the cache, return the current key
        if (val2key[_value] != 0) {
            return val2key[_value];
        }

        // Since 0xFE is a special case, the largest key the cache can
        // hold is 0x0D followed by 15 0xFF's. If the cache length is already that
        // large, fail.
        //                              1 2 3 4 5 6 7 8 9 A B C D E F
        require(key2val.length+1 < 0x0DFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            "cache overflow");

        // Write the value using the next key
        val2key[_value] = key2val.length+1;
        key2val.push(_value);
        return key2val.length;
    }  // cacheWrite



    function _calldataVal(uint startByte, uint length)
        private pure returns (uint) 
    {
        uint _retVal;

        require(length < 0x21,
            "_calldataVal length limit is 32 bytes");
        require(length + startByte <= msg.data.length,
            "_calldataVal trying to read beyond calldatasize");

        assembly {
            _retVal := calldataload(startByte)
        }
        _retVal = _retVal >> (256-length*8);

        return _retVal;
    } // _calldataVal


    // Read a single parameter from the calldata, starting at _fromByte
    function _readParam(uint _fromByte) internal 
        returns (uint _nextByte, uint _parameterValue) 
    {
        // The first byte tells us how to interpret the rest
        uint8 _firstByte;

        _firstByte = uint8(_calldataVal(_fromByte, 1));

        // Read the value, but do not write it to the cache
        if (_firstByte == uint8(DONT_CACHE))
            return(_fromByte+33, _calldataVal(_fromByte+1, 32));

        // Read the value, and write it to the cache
        if (_firstByte == uint8(INTO_CACHE)) {
            uint _param = _calldataVal(_fromByte+1, 32);
            cacheWrite(_param);
            return(_fromByte+33, _param);
        }

        // If we got here it means that we need to read from the cache

        // Number of extra bytes to read
        uint8 _extraBytes = _firstByte / 16;

        uint _key = (uint256(_firstByte & 0x0F) << (8*_extraBytes)) + 
            _calldataVal(_fromByte+1, _extraBytes);

        return (_fromByte+_extraBytes+1, cacheRead(_key));

    }  // _readParam


    // Read n parameters (functions know how many parameters they expect)
    function _readParams(uint _paramNum) internal returns (uint[256] memory) {
        // The parameters we read
        uint[256] memory params;

        // Parameters start at byte 4, before that it's the function signature
        uint _atByte = 4;

        require(_paramNum < 256, "Can only handle up to 256 function parameters");

        for(uint i=0; i<_paramNum; i++) {
            (_atByte, params[i]) = _readParam(_atByte);
        }

        return(params);
    }   // readParams



    // For testing _readParams, test reading four parameters
    function fourParam() public 
        returns (uint256,uint256,uint256,uint256) 
    {
        uint[256] memory params;
        params = _readParams(4);
        return (params[0], params[1], params[2], params[3]);
    }    // fourParam

    // Get a value, return bytes that will encode it (using the cache if possible)
    function encodeVal(uint _val) public view returns(bytes memory) {
        uint _key = val2key[_val];

        // The value isn't in the cache yet, add it
        if (_key == 0)
            return bytes.concat(INTO_CACHE, bytes32(_val));

        // If the key is <0x10, return it as a single byte
        if (_key < 0x10)
            return bytes.concat(bytes1(uint8(_key)));

        // Two byte value, encoded as 0x1vvv
        if (_key < 0x1000)
            return bytes.concat(bytes2(uint16(_key) | 0x1000));

        // There is probably a clever way to do the following lines as a loop,
        // but it's a view function so I'm optimizing for programmer time and
        // simplicity.

        if (_key < 16*256**2)
            return bytes.concat(bytes3(uint24(_key) | (0x2 * 16 * 256**2)));
        if (_key < 16*256**3)
            return bytes.concat(bytes4(uint32(_key) | (0x3 * 16 * 256**3)));
        if (_key < 16*256**4)
            return bytes.concat(bytes5(uint40(_key) | (0x4 * 16 * 256**4)));
        if (_key < 16*256**5)
            return bytes.concat(bytes6(uint48(_key) | (0x5 * 16 * 256**5)));
        if (_key < 16*256**6)  
            return bytes.concat(bytes7(uint56(_key) | (0x6 * 16 * 256**6))); 
        if (_key < 16*256**7)
            return bytes.concat(bytes8(uint64(_key) | (0x7 * 16 * 256**7)));                                                   
        if (_key < 16*256**8)
            return bytes.concat(bytes9(uint72(_key) | (0x8 * 16 * 256**8)));
        if (_key < 16*256**9)
            return bytes.concat(bytes10(uint80(_key) | (0x9 * 16 * 256**9)));
        if (_key < 16*256**10)
            return bytes.concat(bytes11(uint88(_key) | (0xA * 16 * 256**10)));
        if (_key < 16*256**11)
            return bytes.concat(bytes12(uint96(_key) | (0xB * 16 * 256**11)));
        if (_key < 16*256**12)  
            return bytes.concat(bytes13(uint104(_key) | (0xC * 16 * 256**12))); 
        if (_key < 16*256**13)
            return bytes.concat(bytes14(uint112(_key) | (0xD * 16 * 256**13)));
        if (_key < 16*256**14)
            return bytes.concat(bytes15(uint120(_key) | (0xE * 16 * 256**14)));
        if (_key < 16*256**15)
            return bytes.concat(bytes16(uint128(_key) | (0xF * 16 * 256**15)));

        // If we get here, something is wrong.
        revert("Error in encodeVal, should not happen");
    } // encodeVal

}  // Cache

