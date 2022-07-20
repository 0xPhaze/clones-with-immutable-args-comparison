// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "../ERC1967Proxy.sol";

bytes32 constant arg1 = 0x1111111111111111aaaaaaaaaaaaaaaa1111111111111111aaaaaaaaaaaaaaaa;
bytes32 constant arg2 = 0x2222222222222222bbbbbbbbbbbbbbbb2222222222222222bbbbbbbbbbbbbbbb;
bytes32 constant arg3 = 0x3333333333333333cccccccccccccccc3333333333333333cccccccccccccccc;

/// @title ERC1967 Proxy With 3 Immutable Args
/// @author phaze (https://github.com/0xPhaze/proxies-with-immutable-args)
/// @notice supports up to 3 bytes32 immutable args
/// @dev the arguments bytes length is stored in the last 2 bytes of the calldata
contract ERC1967ProxyWith3ImmutableArgs is ERC1967 {
    constructor(address logic, bytes memory initCalldata) payable {
        _upgradeToAndCall(logic, initCalldata);
    }

    fallback() external payable {
        assembly {
            calldatacopy(0, 0, calldatasize())

            mstore(calldatasize(), arg1)
            mstore(add(calldatasize(), 0x20), arg2)
            mstore(add(calldatasize(), 0x40), arg3)
            mstore(add(calldatasize(), 0x60), shl(240, 0x60))

            let success := delegatecall(gas(), sload(ERC1967_PROXY_STORAGE_SLOT), 0, add(calldatasize(), 0x62), 0, 0)

            returndatacopy(0, 0, returndatasize())

            if iszero(success) {
                revert(0, returndatasize())
            }

            return(0, returndatasize())
        }
    }
}

/// @title ERC1967 Proxy With 2 Immutable Args
/// @author phaze (https://github.com/0xPhaze/proxies-with-immutable-args)
/// @notice supports up to 2 bytes32 immutable args
/// @dev the arguments bytes length is stored in the last 2 bytes of the calldata
contract ERC1967ProxyWith2ImmutableArgs is ERC1967 {
    constructor(address logic, bytes memory initCalldata) payable {
        _upgradeToAndCall(logic, initCalldata);
    }

    fallback() external payable {
        assembly {
            calldatacopy(0, 0, calldatasize())

            mstore(calldatasize(), arg1)
            mstore(add(calldatasize(), 0x20), arg2)
            mstore(add(calldatasize(), 0x40), shl(240, 0x40))

            let success := delegatecall(gas(), sload(ERC1967_PROXY_STORAGE_SLOT), 0, add(calldatasize(), 0x42), 0, 0)

            returndatacopy(0, 0, returndatasize())

            if iszero(success) {
                revert(0, returndatasize())
            }

            return(0, returndatasize())
        }
    }
}

/// @title ERC1967 Proxy With 1 Immutable Arg
/// @author phaze (https://github.com/0xPhaze/proxies-with-immutable-args)
/// @notice supports up to 1 bytes32 immutable arg
/// @dev the arguments bytes length is stored in the last 2 bytes of the calldata
contract ERC1967ProxyWith1ImmutableArgs is ERC1967 {
    constructor(address logic, bytes memory initCalldata) payable {
        _upgradeToAndCall(logic, initCalldata);
    }

    fallback() external payable {
        assembly {
            calldatacopy(0, 0, calldatasize())

            mstore(calldatasize(), arg1)
            mstore(add(calldatasize(), 0x20), shl(240, 0x20))

            let success := delegatecall(gas(), sload(ERC1967_PROXY_STORAGE_SLOT), 0, add(calldatasize(), 0x22), 0, 0)

            returndatacopy(0, 0, returndatasize())

            if iszero(success) {
                revert(0, returndatasize())
            }

            return(0, returndatasize())
        }
    }
}
