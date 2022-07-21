// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library utils {
    /// @notice split data to chunks of 32 bytes
    function splitToBytes32(bytes memory data) internal pure returns (bytes32[] memory split) {
        uint256 numEl = (data.length + 31) >> 5;

        split = new bytes32[](numEl);

        uint256 loc;

        assembly {
            loc := add(split, 32)
        }

        mstore(loc, data);
    }

    /// @notice stores data at offset while preserving existing memory
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

    /// @notice gets minimum required bytes to store value
    function getRequiredBytes(uint256 value) internal pure returns (uint256) {
        uint256 numBytes = 1;

        for (; numBytes < 32; ++numBytes) {
            value = value >> 8;
            if (value == 0) break;
        }

        return numBytes;
    }
}
