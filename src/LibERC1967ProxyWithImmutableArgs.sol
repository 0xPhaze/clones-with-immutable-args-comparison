// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";

import {verifyIsProxiableContract, proxyRuntimeCode, proxyCreationCode} from "./ProxyCreationCode.sol";

/// @title Library for deploying ERC1967 proxies with immutable args
/// @author phaze (https://github.com/0xPhaze/proxies-with-immutable-args)
/// @notice Inspired by (https://github.com/wighawag/clones-with-immutable-args)
/// @notice Supports up to 3 bytes32 "immutable" arguments
/// @notice These contracts are "verifiable" through etherscan
/// @dev Arguments are appended to calldata on any call
library LibERC1967ProxyWithImmutableArgs {
    // ---------------------------------------------------------------------------------------
    // ERC1967 Proxy With Immutable Args
    // - created from bytecode
    // ---------------------------------------------------------------------------------------

    /// @notice Deploys an ERC1967 proxy with immutable bytes args (max. 2^16 - 1 bytes)
    /// @notice This contract is not verifiable on etherscan
    /// @param implementation address points to the implementation contract
    /// @param immutableArgs bytes array of immutable args
    /// @return addr address of the deployed proxy
    function deployProxyWithImmutableArgs(
        address implementation,
        bytes memory initCalldata,
        bytes memory immutableArgs
    ) internal returns (address) {
        verifyIsProxiableContract(implementation);

        bytes memory runtimeCode = proxyRuntimeCode(immutableArgs);
        bytes memory creationCode = proxyCreationCode(implementation, runtimeCode, initCalldata);

        return deployCode(creationCode);
    }

    // ---------------------------------------------------------------------------------------
    // Verifiable ERC1967 Proxies With Immutable Args
    // - fixed size {1,2,3} bytes32 args
    // - obtained from solidity code in `reference/ERC1967ProxyWithImmutableArgs.sol`
    // - these can be verified on etherscan by modifying solidity code with appropriate args
    // ---------------------------------------------------------------------------------------

    /// @notice Deploys an ERC1967 proxy with 1 immutable arg
    /// @param implementation address points to the implementation contract
    /// @param initCalldata bytes is the encoded calldata used to call logic for initialization
    /// @param arg1_ first immutable arg
    /// @return addr address of the deployed proxy
    function deployProxyVerifiable(
        address implementation,
        bytes memory initCalldata,
        bytes32 arg1_
    ) internal returns (address addr) {
        bytes memory bytecode = abi.encodePacked(
            hex"60806040526040516102a43803806102a483398101604081905261002291610100565b61002c8282610033565b50506101f2565b813b610047576309ee12d56000526004601cfd5b6352d1902d600052602060006004601c6000865af18061006657600080fd5b6000516000805160206102848339815191521461008b576303ed501d6000526004601cfd5b827fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b600080a2815180156100d5576000808260208601875af49150816100d5573d6000803e3d6000fd5b50505060008051602061028483398151915255565b634e487b7160e01b600052604160045260246000fd5b6000806040838503121561011357600080fd5b82516001600160a01b038116811461012a57600080fd5b602084810151919350906001600160401b038082111561014957600080fd5b818601915086601f83011261015d57600080fd5b81518181111561016f5761016f6100ea565b604051601f8201601f19908116603f01168101908382118183101715610197576101976100ea565b8160405282815289868487010111156101af57600080fd5b600093505b828410156101d157848401860151818501870152928501926101b4565b828411156101e25760008684830101525b8096505050505050509250929050565b6084806102006000396000f3fe608060405236600080377f",
            arg1_,
            hex"3652602060f01b60203601526000806022360160007f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e806071573d6000fd5b503d6000f3fea164736f6c634300080d000a360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
            abi.encode(implementation, initCalldata)
        );

        return deployCode(bytecode);
    }

    /// @notice Deploys an ERC1967 proxy with 2 immutable args
    /// @param implementation address points to the implementation contract
    /// @param initCalldata bytes is the encoded calldata used to call logic for initialization
    /// @param arg1_ first immutable arg
    /// @param arg2_ second immutable arg
    /// @return addr address of the deployed proxy
    function deployProxyVerifiable(
        address implementation,
        bytes memory initCalldata,
        bytes32 arg1_,
        bytes32 arg2_
    ) internal returns (address addr) {
        bytes memory bytecode = abi.encodePacked(
            hex"60806040526040516102ca3803806102ca83398101604081905261002291610100565b61002c8282610033565b50506101f2565b813b610047576309ee12d56000526004601cfd5b6352d1902d600052602060006004601c6000865af18061006657600080fd5b6000516000805160206102aa8339815191521461008b576303ed501d6000526004601cfd5b827fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b600080a2815180156100d5576000808260208601875af49150816100d5573d6000803e3d6000fd5b5050506000805160206102aa83398151915255565b634e487b7160e01b600052604160045260246000fd5b6000806040838503121561011357600080fd5b82516001600160a01b038116811461012a57600080fd5b602084810151919350906001600160401b038082111561014957600080fd5b818601915086601f83011261015d57600080fd5b81518181111561016f5761016f6100ea565b604051601f8201601f19908116603f01168101908382118183101715610197576101976100ea565b8160405282815289868487010111156101af57600080fd5b600093505b828410156101d157848401860151818501870152928501926101b4565b828411156101e25760008684830101525b8096505050505050509250929050565b60aa806102006000396000f3fe608060405236600080377f",
            arg1_,
            hex"36527f",
            arg2_,
            hex"6020360152604060f01b60403601526000806042360160007f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e806097573d6000fd5b503d6000f3fea164736f6c634300080d000a360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
            abi.encode(implementation, initCalldata)
        );

        return deployCode(bytecode);
    }

    /// @notice Deploys an ERC1967 proxy with 3 immutable args
    /// @param implementation address points to the implementation contract
    /// @param initCalldata bytes is the encoded calldata used to call logic for initialization
    /// @param arg1_ first immutable arg
    /// @param arg2_ second immutable arg
    /// @param arg3_ third immutable arg
    /// @return addr address of the deployed proxy
    function deployProxyVerifiable(
        address implementation,
        bytes memory initCalldata,
        bytes32 arg1_,
        bytes32 arg2_,
        bytes32 arg3_
    ) internal returns (address addr) {
        bytes memory bytecode = abi.encodePacked(
            hex"60806040526040516102f03803806102f083398101604081905261002291610100565b61002c8282610033565b50506101f2565b813b610047576309ee12d56000526004601cfd5b6352d1902d600052602060006004601c6000865af18061006657600080fd5b6000516000805160206102d08339815191521461008b576303ed501d6000526004601cfd5b827fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b600080a2815180156100d5576000808260208601875af49150816100d5573d6000803e3d6000fd5b5050506000805160206102d083398151915255565b634e487b7160e01b600052604160045260246000fd5b6000806040838503121561011357600080fd5b82516001600160a01b038116811461012a57600080fd5b602084810151919350906001600160401b038082111561014957600080fd5b818601915086601f83011261015d57600080fd5b81518181111561016f5761016f6100ea565b604051601f8201601f19908116603f01168101908382118183101715610197576101976100ea565b8160405282815289868487010111156101af57600080fd5b600093505b828410156101d157848401860151818501870152928501926101b4565b828411156101e25760008684830101525b8096505050505050509250929050565b60d0806102006000396000f3fe608060405236600080377f",
            arg1_,
            hex"36527f",
            arg2_,
            hex"60203601527f",
            arg3_,
            hex"6040360152606060f01b60603601526000806062360160007f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e8060bd573d6000fd5b503d6000f3fea164736f6c634300080d000a360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
            abi.encode(implementation, initCalldata)
        );

        return deployCode(bytecode);
    }

    // ---------------------------------------------------------------------------------------
    // Utils
    // ---------------------------------------------------------------------------------------

    function getFullCalldata() internal pure returns (bytes memory cd) {
        assembly {
            cd := mload(0x40)
            mstore(cd, calldatasize())

            calldatacopy(add(cd, 32), 0, calldatasize())
            mstore(0x40, add(add(cd, 32), calldatasize()))
        }
    }

    /// @notice Reads a packed immutable arg with as uint256
    /// @param argOffset The offset of the arg in the packed data
    /// @param argLen The bytes length of the arg in the packed data
    /// @return arg The arg value
    function getArg(uint256 argOffset, uint256 argLen) internal pure returns (uint256 arg) {
        uint256 offset = getImmutableArgsOffset();
        assembly {
            arg := shr(sub(256, shl(3, argLen)), calldataload(add(offset, argOffset)))
        }
    }

    /// @notice Reads an immutable arg with type bytes32
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
    function getArgBytes32(uint256 argOffset) internal pure returns (bytes32 arg) {
        uint256 offset = getImmutableArgsOffset();
        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }

    /// @notice Reads an immutable arg with type address
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
    function getArgAddress(uint256 argOffset) internal pure returns (address arg) {
        uint256 offset = getImmutableArgsOffset();
        assembly {
            arg := shr(96, calldataload(add(offset, argOffset)))
        }
    }

    /// @notice Reads an immutable arg with type uint256
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
    function getArgUint256(uint256 argOffset) internal pure returns (uint256 arg) {
        uint256 offset = getImmutableArgsOffset();
        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }

    /// @notice Reads an immutable arg with type uint128
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
    function getArgUint128(uint256 argOffset) internal pure returns (uint128 arg) {
        uint256 offset = getImmutableArgsOffset();
        assembly {
            arg := shr(128, calldataload(add(offset, argOffset)))
        }
    }

    /// @notice Reads an immutable arg with type uint64
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
    function getArgUint64(uint256 argOffset) internal pure returns (uint64 arg) {
        uint256 offset = getImmutableArgsOffset();
        assembly {
            arg := shr(192, calldataload(add(offset, argOffset)))
        }
    }

    /// @notice Reads an immutable arg with type uint40
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
    function getArgUint40(uint256 argOffset) internal pure returns (uint40 arg) {
        uint256 offset = getImmutableArgsOffset();
        assembly {
            arg := shr(216, calldataload(add(offset, argOffset)))
        }
    }

    /// @notice Reads an immutable arg with type uint8
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
    function getArgUint8(uint256 argOffset) internal pure returns (uint8 arg) {
        uint256 offset = getImmutableArgsOffset();
        assembly {
            arg := shr(248, calldataload(add(offset, argOffset)))
        }
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

    // ---------------------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------------------

    /// @notice Deploys bytecode using create
    /// @param bytecode deployment code
    /// @return addr address of the deployed contract
    function deployCode(bytes memory bytecode) internal returns (address payable addr) {
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        if (addr.code.length == 0) revert();
    }
}
