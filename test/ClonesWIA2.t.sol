// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {LibClonesWIA} from "/LibClonesWIA.sol";
import {TestImmutableArgsGas} from "./TestGas.sol";

// ---------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------

contract MockVoid {
    fallback() external payable {}
}

contract MockGetMsgData {
    fallback() external payable {
        assembly {
            calldatacopy(0, 0, calldatasize())
            return(0, calldatasize())
        }
    }
}

contract MockGetImmutableArgsLen {
    fallback() external payable {
        uint256 size = LibClonesWIA.getImmutableArgsLen2();
        assembly {
            mstore(0, size)
            return(0, 0x20)
        }
    }
}

contract MockGetImmutableArgsOffset {
    fallback() external payable {
        uint256 offset = LibClonesWIA.getImmutableArgsOffset2();
        assembly {
            mstore(0, offset)
            return(0, 0x20)
        }
    }
}

contract MockGetArgBytes {
    uint256 immutable argOffset;
    uint256 immutable argLen;

    constructor(uint256 argOffset_, uint256 argLen_) {
        argOffset = argOffset_;
        argLen = argLen_;
    }

    fallback() external payable {
        bytes memory arg = LibClonesWIA.getArgBytes2(argOffset, argLen);

        assembly {
            return(add(arg, 0x20), mload(arg))
        }
    }
}

// ---------------------------------------------------------------------
// Immutable Args Type 2 Gas Tests
// ---------------------------------------------------------------------

contract TestImmutableArgsGas2 is TestImmutableArgsGas {
    function deployMockCloneWIA(
        uint256 readOffset,
        uint256 readSize,
        bytes memory immutableArgs
    ) internal override returns (address) {
        address implementation = address(new MockGetArgBytes(readOffset, readSize));

        return LibClonesWIA.deployCloneWithImmutableArgs2(implementation, "", immutableArgs);
    }

    function deployMockVoidCloneWIA(bytes memory immutableArgs) internal override returns (address) {
        address implementation = address(new MockVoid());

        return LibClonesWIA.deployCloneWithImmutableArgs2(implementation, "", immutableArgs);
    }
}

// ---------------------------------------------------------------------
// Immutable Args Type 2 Tests
// ---------------------------------------------------------------------

contract TestImmutableArgs2 is Test {
    /* ------------- tests type 2 ------------- */

    function test_getMsgData(bytes memory randomCalldata, bytes memory immutableArgs) public {
        address clone = LibClonesWIA.deployCloneWithImmutableArgs2(address(new MockGetMsgData()), "", immutableArgs);

        (, bytes memory returndata) = address(clone).call(randomCalldata);

        assertEq(returndata, randomCalldata);
    }

    function test_getArgsLen(bytes memory randomCalldata, bytes memory immutableArgs) public {
        address clone = LibClonesWIA.deployCloneWithImmutableArgs2(
            address(new MockGetImmutableArgsLen()),
            "",
            immutableArgs
        );

        (, bytes memory returndata) = address(clone).call(randomCalldata);

        uint256 len = abi.decode(returndata, (uint256));

        assertEq(len, immutableArgs.length);
    }

    function test_getArgsOffset(bytes memory randomCalldata, bytes memory immutableArgs) public {
        address clone = LibClonesWIA.deployCloneWithImmutableArgs2(
            address(new MockGetImmutableArgsOffset()),
            "",
            immutableArgs
        );

        (, bytes memory returndata) = address(clone).call(randomCalldata);

        uint256 offset = abi.decode(returndata, (uint256));

        assertEq(offset, clone.code.length - immutableArgs.length - 2);
    }

    function test_getArgBytes(
        bytes calldata randomCalldata,
        bytes calldata immutableArgs,
        uint16 readArgOffset,
        uint16 readArgLen
    ) public {
        readArgOffset = uint16(bound(readArgOffset, 0, immutableArgs.length));
        readArgLen = uint16(bound(readArgLen, 0, immutableArgs.length - readArgOffset));

        address clone = LibClonesWIA.deployCloneWithImmutableArgs2(
            address(new MockGetArgBytes(readArgOffset, readArgLen)),
            "",
            immutableArgs
        );

        (, bytes memory returndata) = address(clone).call(randomCalldata);

        assertEq(returndata, immutableArgs[readArgOffset:readArgOffset + readArgLen]);
    }
}
