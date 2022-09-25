// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/cloneCreationCode.sol";

library LibClonesWIA {
    function deployCloneWithImmutableArgs(
        address implementation,
        bytes memory initCalldata,
        bytes memory immutableArgs
    ) internal returns (address addr) {
        bytes memory runtimeCode = cloneRuntimeCode(implementation, immutableArgs);
        bytes memory creationCode = cloneCreationCode(implementation, runtimeCode, initCalldata);

        assembly {
            addr := create(0, add(creationCode, 0x20), mload(creationCode))
        }

        if (addr.code.length == 0) revert();
    }

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

    function getImmutableArgsOffset() internal pure returns (uint256 offset) {
        assembly {
            let numBytes := shr(240, calldataload(sub(calldatasize(), 2)))
            offset := sub(sub(calldatasize(), 2), numBytes)
        }
    }

    function getImmutableArgsLen() internal pure returns (uint256 size) {
        assembly {
            size := shr(240, calldataload(sub(calldatasize(), 2)))
        }
    }

    /* ------------- type 2 ------------- */

    function deployCloneWithImmutableArgs2(
        address implementation,
        bytes memory initCalldata,
        bytes memory immutableArgs
    ) internal returns (address addr) {
        bytes memory runtimeCode = cloneRuntimeCode2(implementation, immutableArgs);
        bytes memory creationCode = cloneCreationCode(implementation, runtimeCode, initCalldata);

        assembly {
            addr := create(0, add(creationCode, 0x20), mload(creationCode))
        }

        if (addr.code.length == 0) revert();
    }

    function getArgBytes2(uint256 argOffset, uint256 argLen) internal view returns (bytes memory arg) {
        uint256 offset = getImmutableArgsOffset2();
        assembly {
            // position arg bytes at free memory position
            arg := mload(0x40)

            // store size
            mstore(arg, argLen)

            // copy data
            extcodecopy(address(), add(arg, 0x20), add(offset, argOffset), argLen)

            // update free memmory pointer
            mstore(0x40, add(add(arg, 0x20), argLen))
        }
    }

    function getImmutableArgsOffset2() internal view returns (uint256 offset) {
        assembly {
            let codeSize := sub(extcodesize(address()), 2)
            extcodecopy(address(), 0, codeSize, 2)
            let size := shr(240, mload(0))
            offset := sub(codeSize, size)
        }
    }

    function getImmutableArgsLen2() internal view returns (uint256 size) {
        assembly {
            extcodecopy(address(), 0, sub(extcodesize(address()), 2), 2)
            size := shr(240, mload(0))
        }
    }

    /* ------------- type 3 ------------- */

    function deployCloneWithImmutableArgs3(
        address implementation,
        bytes memory initCalldata,
        bytes memory immutableArgs
    ) internal returns (address addr) {
        bytes memory runtimeCode = cloneRuntimeCode3(implementation, immutableArgs);
        bytes memory creationCode = cloneCreationCode(implementation, runtimeCode, initCalldata);

        assembly {
            addr := create(0, add(creationCode, 0x20), mload(creationCode))
        }

        if (addr.code.length == 0) revert();
    }

    bytes4 constant TYPE_3_MAGIC_VALUE = hex"33333333";

    function getArgBytes3(uint256 argOffset, uint256 argLen) internal view returns (bytes memory arg) {
        (bool success, bytes memory returndata) = address(this).staticcall(
            abi.encodeWithSelector(TYPE_3_MAGIC_VALUE, argOffset, argLen)
        );
        require(success, "call failed");
        arg = returndata;
    }
}
