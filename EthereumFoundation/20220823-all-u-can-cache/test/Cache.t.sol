// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";


// Need to run `forge test -vv` for the console.
import "forge-std/console.sol";
import "src/Cache.sol";

contract CacheTest is Test {
    Cache cache;

    function setUp() public {
        cache = new Cache();        
    }

    function testCaching() public {

        for(uint i=1; i<5000; i++) {
            cache.cacheWrite(i*i);
        }        

        for(uint i=1; i<5000; i++) {
            assertEq(cache.cacheRead(i), i*i);
        }
    }    // testCaching

    // Cache the same value multiple times, ensure that the key stays
    // the same
    function testRepeatCaching() public {
        for(uint i=1; i<100; i++) {
            uint _key1 = cache.cacheWrite(i);
            uint _key2 = cache.cacheWrite(i);            
            assertEq(_key1, _key2);
        }

        for(uint i=1; i<100; i+=3) {
            uint _key = cache.cacheWrite(i);
            assertEq(_key, i);
        }
    }    // testRepeatCaching    


    // Read a uint from a memory buffer (to make sure we get back the parameters
    // we sent out) 
    function toUint256(bytes memory _bytes, uint256 _start) internal pure 
        returns (uint256) 
    {
        require(_bytes.length >= _start + 32, "toUint256_outOfBounds");
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }     // toUint256

    // Function signature for fourParams(), courtesy of
    // https://www.4byte.directory/signatures/?bytes4_signature=0x3edc1e6d
    bytes4 constant FOUR_PARAMS = 0x3edc1e6d;

    // Just some constant values to see we're getting the correct values back
    uint256 constant VAL_A = 0xDEAD60A7;
    uint256 constant VAL_B =     0xBEEF;
    uint256 constant VAL_C =     0x600D;
    uint256 constant VAL_D = 0x600D60A7;

    function testReadParam() public {
        address _cacheAddr = address(cache);
        bool _success;
        bytes memory _callInput;
        bytes memory _callOutput;

        // First call, the cache is empty
        _callInput = bytes.concat(
            FOUR_PARAMS,

            // First value, add it to the cache 
            cache.INTO_CACHE(),   
            bytes32(VAL_A),

            // Second value, don't add it to the cache
            cache.DONT_CACHE(),
            bytes32(VAL_B),

            // Third and fourth values, same value
            cache.INTO_CACHE(),
            bytes32(VAL_C),
            cache.INTO_CACHE(),
            bytes32(VAL_C)
        );
        (_success, _callOutput) = _cacheAddr.call(_callInput);
        assertEq(_success, true);
        assertEq(cache.cacheRead(1), VAL_A);
        assertEq(cache.cacheRead(2), VAL_C); 
        assertEq(toUint256(_callOutput,0), VAL_A);
        assertEq(toUint256(_callOutput,32), VAL_B);
        assertEq(toUint256(_callOutput,64), VAL_C);
        assertEq(toUint256(_callOutput,96), VAL_C);

        // Second call, we can use the cache
        _callInput = bytes.concat(
            FOUR_PARAMS,

            // First value in the Cache
            bytes1(0x01),   

            // Second value, don't add it to the cache
            cache.DONT_CACHE(),
            bytes32(VAL_B),

            // Third and fourth values, same value
            bytes1(0x02),
            bytes1(0x02)
        );
        (_success, _callOutput) = _cacheAddr.call(_callInput);
        assertEq(_success, true);
        assertEq(toUint256(_callOutput,0), VAL_A);
        assertEq(toUint256(_callOutput,32), VAL_B);
        assertEq(toUint256(_callOutput,64), VAL_C);
        assertEq(toUint256(_callOutput,96), VAL_C);

    }   // testReadParam


    function testEncodeVal() public {
        address _cacheAddr = address(cache);
        bool _success;
        bytes memory _callInput;
        bytes memory _callOutput;

        // First call, the cache is empty
        // Second call, we can use the cache
        _callInput = bytes.concat(
            FOUR_PARAMS,
            cache.encodeVal(VAL_A),
            cache.encodeVal(VAL_B),
            cache.encodeVal(VAL_C),
            cache.encodeVal(VAL_D)
        );                        
        (_success, _callOutput) = _cacheAddr.call(_callInput);
        assertEq(_success, true);
        assertEq(toUint256(_callOutput,0), VAL_A);
        assertEq(toUint256(_callOutput,32), VAL_B);
        assertEq(toUint256(_callOutput,64), VAL_C);
        assertEq(toUint256(_callOutput,96), VAL_D);
        assertEq(_callInput.length, 4+33*4);

        // Second call, we can use the cache
        _callInput = bytes.concat(
            FOUR_PARAMS,
            cache.encodeVal(VAL_A),
            cache.encodeVal(VAL_B),
            cache.encodeVal(VAL_C),
            cache.encodeVal(VAL_D)
        );                        
        (_success, _callOutput) = _cacheAddr.call(_callInput);
        assertEq(_success, true);
        assertEq(toUint256(_callOutput,0), VAL_A);
        assertEq(toUint256(_callOutput,32), VAL_B);
        assertEq(toUint256(_callOutput,64), VAL_C);
        assertEq(toUint256(_callOutput,96), VAL_D);
        assertEq(_callInput.length, 4+1*4);
    }   // testEncodeVal


    // Test encodeVal when the key is more than a single byte
    // Maximum three bytes because filling the cache to four bytes takes
    // too long.
    function testEncodeValBig() public {
        // Put a number of values in the cache.
        // To keep things simnple, use key n for value n.
        for(uint i=1; i<0x1FFF; i++) {
            cache.cacheWrite(i);
        }        

        address _cacheAddr = address(cache);
        bool _success;
        bytes memory _callInput;
        bytes memory _callOutput;

        _callInput = bytes.concat(
            FOUR_PARAMS,
            cache.encodeVal(0x000F),   // One byte        0x0F
            cache.encodeVal(0x0010),   // Two bytes     0x1010
            cache.encodeVal(0x0100),   // Two bytes     0x1100
            cache.encodeVal(0x1000)    // Three bytes 0x201000 
        );    
        (_success, _callOutput) = _cacheAddr.call(_callInput);
        assertEq(_success, true);
        assertEq(toUint256(_callOutput,0),  0x000F);
        assertEq(toUint256(_callOutput,32), 0x0010);
        assertEq(toUint256(_callOutput,64), 0x0100);
        assertEq(toUint256(_callOutput,96), 0x1000);
        assertEq(_callInput.length, 4+1+2+2+3);

    }    // testEncodeValBig

}        // CacheTest
