// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC1967_PROXY_STORAGE_SLOT} from "/ERC1967Proxy.sol";
import {UUPSUpgrade} from "/UUPSUpgrade.sol";
import {utils} from "../utils/utils.sol";

contract MockUUPSUpgrade is UUPSUpgrade {
    uint256 public immutable version;

    constructor(uint256 version_) {
        version = version_;
    }

    function implementation() public view returns (address impl) {
        assembly {
            impl := sload(ERC1967_PROXY_STORAGE_SLOT)
        }
    }

    function forceUpgrade(address impl) public {
        assembly {
            sstore(ERC1967_PROXY_STORAGE_SLOT, impl)
        }
    }

    function scrambleStorage() public {
        utils.scrambleStorage(0, 100);
    }

    function _authorizeUpgrade() internal virtual override {}
}
