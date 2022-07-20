// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/Test.sol";

library utils {
    function mdump(uint256 location, uint256 numSlots) internal view {
        bytes32 m;
        for (uint256 i; i < numSlots; i++) {
            assembly {
                m := mload(add(location, mul(32, i)))
            }
            console.log(location, 32 * i);
            console.logBytes32(m);
        }
    }

    function mdump(bytes memory arg) internal view {
        mdump(mloc(arg), (arg.length + 1) / 32 + 1);
    }

    function mdump(bytes32[] memory arg) internal view {
        mdump(mloc(arg), arg.length + 1);
    }

    function mloc(bytes memory arr) internal pure returns (uint256 loc) {
        assembly {
            loc := arr
        }
    }

    function mloc(bytes32[] memory arr) internal pure returns (uint256 loc) {
        assembly {
            loc := arr
        }
    }

    function scrambleMem(bytes32[] memory arr) internal pure {
        return scrambleMem(mloc(arr) + 32, arr.length * 32);
    }

    function scrambleMem(uint256 offset, uint256 bytesLen) internal pure {
        uint256 slot;
        bytes32 rand;

        uint256 lastFullSlot = bytesLen >> 5;

        for (; slot < lastFullSlot; slot++) {
            rand = keccak256(abi.encodePacked(slot));

            assembly {
                mstore(add(offset, mul(slot, 32)), rand)
            }
        }

        uint256 mask = type(uint256).max >> ((bytesLen & 31) << 3);

        rand = keccak256(abi.encodePacked(slot));

        assembly {
            let location := add(offset, mul(slot, 32))
            let data := mload(location)
            mstore(location, or(and(data, mask), and(rand, not(mask))))
        }
    }

    function mstore(
        uint256 offset,
        bytes32 val,
        uint256 bytesLen
    ) internal pure {
        assembly {
            let mask := shr(mul(bytesLen, 8), sub(0, 1))
            mstore(offset, or(and(val, not(mask)), and(mload(offset), mask)))
        }
    }

    function scrambleStorage(uint256 offset, uint256 numSlots) public {
        bytes32 rand;
        for (uint256 slot; slot < numSlots; slot++) {
            rand = keccak256(abi.encodePacked(offset + slot));

            assembly {
                sstore(add(slot, offset), rand)
            }
        }
    }

    function splitToBytes32(bytes memory data) internal pure returns (bytes32[] memory split) {
        uint256 numEl = (data.length + 31) >> 5;

        split = new bytes32[](numEl);

        uint256 loc;

        assembly {
            loc := add(split, 32)
        }

        mstore(loc, data);
    }

    function mstore(uint256 offset, bytes memory data) internal pure {
        uint256 slot;

        uint256 size = data.length;

        uint256 lastFullSlot = size >> 5;

        for (; slot < lastFullSlot; slot++) {
            assembly {
                let rel_ptr := mul(slot, 32)
                let chunk := mload(add(add(data, 32), rel_ptr))
                mstore(add(offset, rel_ptr), chunk)
            }
        }

        assembly {
            let mask := shr(shl(3, and(size, 31)), sub(0, 1))
            let rel_ptr := mul(slot, 32)
            let chunk := mload(add(add(data, 32), rel_ptr))
            let prev_data := mload(add(offset, rel_ptr))
            mstore(add(offset, rel_ptr), or(and(chunk, not(mask)), and(prev_data, mask)))
        }
    }

    function getRequiredBytes(uint256 value) internal pure returns (uint256) {
        uint256 numBytes = 1;

        for (; numBytes < 32; ++numBytes) {
            value = value >> 8;
            if (value == 0) break;
        }

        return numBytes;
    }
}
