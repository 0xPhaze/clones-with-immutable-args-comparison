// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {verifyIsProxiableContract, proxyRuntimeCode, proxyCreationCode} from "./utils/proxyCreationCode.sol";

/// @title Library for deploying ERC1967 proxies with immutable args
/// @author phaze (https://github.com/0xPhaze/proxies-with-immutable-args)
/// @notice Inspired by (https://github.com/wighawag/clones-with-immutable-args)
/// @notice Supports up to 3 bytes32 "immutable" arguments
/// @notice These contracts are "verifiable" through etherscan
/// @dev Arguments are appended to calldata on any call
library LibERC1967ProxyWithImmutableArgs {
    /// @notice Deploys an ERC1967 proxy with immutable bytes args (max. 2^16 - 1 bytes)
    /// @notice This contract is not verifiable on etherscan
    /// @param implementation address points to the implementation contract
    /// @param immutableArgs bytes array of immutable args
    /// @return addr address of the deployed proxy
    function deployProxyWithImmutableArgs(
        address implementation,
        bytes memory initCalldata,
        bytes memory immutableArgs
    ) internal returns (address addr) {
        verifyIsProxiableContract(implementation);

        bytes memory runtimecode = proxyRuntimeCode(immutableArgs);
        bytes memory creationcode = proxyCreationCode(implementation, runtimecode, initCalldata);

        assembly {
            addr := create(0, add(creationcode, 0x20), mload(creationcode))
        }

        if (addr.code.length == 0) revert();
    }

    /// @notice Reads a packed immutable arg with as bytes
    /// @param argOffset The offset of the arg in the packed data
    /// @param argLen The bytes length of the arg in the packed data
    /// @return arg The bytes arg value
    function getArgBytes(uint256 argOffset, uint256 argLen) internal pure returns (bytes memory arg) {
        uint256 offset = getImmutableArgsOffset();
        assembly {
            // position arg bytes at free memory position
            arg := mload(0x40)

            // store size
            mstore(arg, argLen)

            // copy data
            calldatacopy(add(arg, 0x20), add(offset, argOffset), argLen)

            // update free memmory pointer
            mstore(0x40, add(add(arg, 0x20), argLen))
        }
    }

    /// @notice Reads a packed immutable arg with as uint256
    /// @param argOffset The offset of the arg in the packed data
    /// @param argLen The bytes length of the arg in the packed data
    /// @return arg The uint256 arg value
    function getArg(uint256 argOffset, uint256 argLen) internal pure returns (uint256 arg) {
        assembly {
            let sizeOffset := sub(calldatasize(), 2) // offset for size location
            let size := shr(240, calldataload(sizeOffset)) // immutableArgs bytes size
            let offset := sub(sizeOffset, size) // immutableArgs offset

            // load arg (in 32 bytes) and shift right by (256 - argLen * 8) bytes
            arg := shr(shl(3, sub(32, argLen)), calldataload(add(offset, argOffset)))

            // mask if trying to load too much calldata (argOffset + argLen > size)
            // should be users responsibility, though this makes testing easier
            let overload := shl(3, sub(add(argOffset, argLen), size))

            if lt(overload, 257) {
                arg := shl(overload, shr(overload, arg))
            }
        }
    }

    /// @notice Reads an immutable arg with type bytes32
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The bytes32 arg value
    function getArgBytes32(uint256 argOffset) internal pure returns (bytes32 arg) {
        return bytes32(getArg(argOffset, 32));
    }

    /// @notice Reads an immutable arg with type address
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The address arg value
    function getArgAddress(uint256 argOffset) internal pure returns (address arg) {
        uint256 offset = getImmutableArgsOffset();
        assembly {
            arg := shr(96, calldataload(add(offset, argOffset)))
        }
    }

    /// @notice Reads an immutable arg with type uint256
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The uint256 arg value
    function getArgUint256(uint256 argOffset) internal pure returns (uint256 arg) {
        return getArg(argOffset, 32);
    }

    /// @notice Reads an immutable arg with type uint128
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The uint128 arg value
    function getArgUint128(uint256 argOffset) internal pure returns (uint128 arg) {
        return uint128(getArg(argOffset, 16));
    }

    /// @notice Reads an immutable arg with type uint64
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The uint64 arg value
    function getArgUint64(uint256 argOffset) internal pure returns (uint64 arg) {
        return uint64(getArg(argOffset, 8));
    }

    /// @notice Reads an immutable arg with type uint40
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The uint40 arg value
    function getArgUint40(uint256 argOffset) internal pure returns (uint40 arg) {
        return uint40(getArg(argOffset, 5));
    }

    /// @notice Reads an immutable arg with type uint8
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The uint8 arg value
    function getArgUint8(uint256 argOffset) internal pure returns (uint8 arg) {
        return uint8(getArg(argOffset, 1));
    }

    /// @notice Gets the starting location in bytes in calldata for immutable args
    /// @return offset calldata bytes offset for immutable args
    function getImmutableArgsOffset() internal pure returns (uint256 offset) {
        assembly {
            let numBytes := shr(240, calldataload(sub(calldatasize(), 2)))
            offset := sub(sub(calldatasize(), 2), numBytes)
        }
    }

    /// @notice Gets the size in bytes of immutable args
    /// @return size bytes size of immutable args
    function getImmutableArgsLen() internal pure returns (uint256 size) {
        assembly {
            size := shr(240, calldataload(sub(calldatasize(), 2)))
        }
    }
}
