// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {verifyIsProxiableContract, proxyRuntimeCode, proxyCreationCode} from "/utils/proxyCreationCode.sol";
import {LibERC1967ProxyWithImmutableArgs} from "/LibERC1967ProxyWithImmutableArgs.sol";

/// @notice wrapper contract for lib
/// @notice forge testing doesn't work well with libs..
/// @notice should only be used for testing
contract ProxyTestDeployer {
    function deployProxyWithImmutableArgs(
        address implementation,
        bytes memory initCalldata,
        bytes memory immutableArgs
    ) public returns (address) {
        verifyIsProxiableContract(implementation);

        bytes memory runtimeCode = proxyRuntimeCode(immutableArgs);
        bytes memory creationCode = proxyCreationCode(implementation, runtimeCode, initCalldata);

        return deployCodeBubbleUpRevertReason(creationCode);
    }

    /// @notice Should only be used for testing
    /// @notice Reads encoded revert reason in deployed bytecode
    /// @dev This requires `RETURN_REVERT_REASON_ON_FAILURE_TEST`
    /// @dev to be inserted in `initCallcode` to function properly
    function deployCodeBubbleUpRevertReason(bytes memory bytecode) internal returns (address payable addr) {
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))

            // can't get any custom messages out of here...

            let ext_code_size := extcodesize(addr)

            if iszero(ext_code_size) {
                revert(0, 0)
            }

            // encode reason in bytecode just so I can run my tests...
            // by checking if first byte equals 00 (STOP)

            extcodecopy(addr, 0, 0, 1)

            if iszero(mload(0)) {
                let revert_size := sub(ext_code_size, 1)
                extcodecopy(addr, 0, 1, revert_size)
                revert(0, revert_size)
            }
        }
    }
}
