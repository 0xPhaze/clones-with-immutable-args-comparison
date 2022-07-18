// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC1967Proxy, ERC1822, ERC1967_PROXY_STORAGE_SLOT, UPGRADED_EVENT_SIG} from "./ERC1967Proxy.sol";
import {LibERC1967ProxyWithImmutableArgs} from "./LibERC1967ProxyWithImmutableArgs.sol";

import {Test, console} from "forge-std/Test.sol";

error InvalidUUID();
error NotAContract();

contract Mock {
    address public constant test = address(0xb0b);
    bytes32 public constant proxiableUUID = ERC1967_PROXY_STORAGE_SLOT;
}

error InvalidOffset(uint256 expected, uint256 actual);

function getCreationCode(
    address implementation,
    bytes memory runtimeCode,
    bytes memory args
) view returns (bytes memory creationCode) {
    uint256 runtimeCodeSize = runtimeCode.length;
    uint256 argSize = args.length;

    require(runtimeCodeSize + argSize <= type(uint16).max, "too long");

    // runtime code is concatenated with args
    uint16 runtimeSize = uint16(runtimeCodeSize + argSize);

    // this can be part of creationcode, but doesn't have to be
    if (implementation.code.length == 0) revert NotAContract();

    bytes32 uuid = ERC1822(implementation).proxiableUUID();

    if (uuid != ERC1967_PROXY_STORAGE_SLOT) revert InvalidUUID();


    uint8 runtimeOffset = 102;

    creationCode = abi.encodePacked( // prettier-ignore
        // [00] log2(0, 0, UPGRADED_EVENT_SIG, logic)

        hex"73", implementation,                    // PUSH20 imp       | imp
        hex"80"                                     // DUP1             | imp imp
        hex"7f", UPGRADED_EVENT_SIG,                // PUSH32 ues       | ues imp imp
        hex"3d"                                     // RETURNDATASIZE   | 00  ues imp imp
        hex"3d"                                     // RETURNDATASIZE   | 00  00  ues imp imp
        hex"a2"                                     // LOG2             | imp


        // [58] sstore(ERC1967_PROXY_STORAGE_SLOT, implementation)

        hex"7f", ERC1967_PROXY_STORAGE_SLOT,        // PUSH32 pss       | pss imp
        hex"55"                                     // SSTORE           | 


        // [92] codecopy(0, runtimeOffset, runtimeSize)

        hex"61", runtimeSize,                       // PUSH2 rts        | rts
        hex"80"                                     // DUP1             | rts rts
        hex"60", runtimeOffset,                     // PUSH1 rto        | rto rts rts
        hex"3d"                                     // RETURNDATASIZE   | 00  rto rts rts
        hex"39"                                     // CODECOPY         | rts                       | [00, rts) = runtimeCode + args

        // [100] return(0, runtimeSize)

        hex"3d"                                     // RETURNDATASIZE   | 00  rts
        hex"f3"                                     // RETURN
    );

    if (creationCode.length != runtimeOffset) revert InvalidOffset(runtimeOffset, creationCode.length);

    creationCode = abi.encodePacked( // prettier-ignore
        creationCode,
        runtimeCode,
        args,
        uint16(argSize)
    );
}

function getProxyRuntimeCode(uint16 argSize) pure returns (bytes memory runtimeCode) {
    runtimeCode = abi.encodePacked( // prettier-ignore
        // [00] calldatacopy(0, 0, calldatasize())
        hex"36"
        hex"3d"
        hex"3d"
        hex"37"

        // // [00] codecopy(0, sub(codesize(), 2), 2)
        // hex"61", argSize,                           // PUSH2 asz        | asz

        // [04] let success := delegatecall(gas(), sload(ERC1967_PROXY_STORAGE_SLOT), 0, calldatasize(), 0, 0)
        hex"3d"
        hex"3d"
        hex"36"
        hex"3d"
        hex"7f", ERC1967_PROXY_STORAGE_SLOT,
        hex"54"
        hex"5a"
        hex"f4"

        // [2c] returndatacopy(0, 0, returndatasize())
        hex"3d"
        hex"60" hex"00"
        hex"80"
        hex"3e"

        // [31] if success { jump(0x38) }
        hex"60" hex"38"
        hex"57"

        // [34] revert(0, returndatasize())
        hex"3d"
        hex"60" hex"00"
        hex"fd"

        // [38] return(0, returndatasize())
        hex"5b"
        hex"3d"
        hex"60" hex"00"
        hex"f3"

        // [3d] = 61
    );
}

contract TestYul is Test {
    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    address logic;

    function setUp() public {
        Mock mock = new Mock();

        // bytes memory runtimeCode = getProxyRuntimeCode(0);
        // vm.etch(address(logic), runtimeCode);

        // bytes memory runtimeCode = hex"604260005260206000F3";
        bytes memory args = "";
        bytes memory runtimeCode = getProxyRuntimeCode(uint16(args.length));
        bytes memory creationCode = getCreationCode(address(mock), runtimeCode, args);

        logic = LibERC1967ProxyWithImmutableArgs.deployCode(creationCode);

        // console.logBytes32(bytes32(runtimeCode.length));
        // console.log(runtimeCode.length);
    }

    /* ------------- helpers ------------- */

    function test_yul() public {
        address t = Mock(logic).test();

        console.logAddress(t);
    }
}

// // re-run all tests in "./UUPSUpgrade.t.sol"
// import {TestUUPSUpgrade, LogicV1, LogicV2} from "./UUPSUpgrade.t.sol";

// contract TestYulUPS is TestUUPSUpgrade {
//     function deployProxy(address implementation, bytes memory initCalldata) internal override returns (address) {
//         bytes memory runtimeCode = getProxyRuntimeCode();
//         bytes memory creationCode = getCreationCode(address(implementation), runtimeCode, initCalldata);

//         return deployCode(creationCode);
//     }
// }
