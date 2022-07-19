// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {ERC1967Proxy, ERC1822, ERC1967_PROXY_STORAGE_SLOT, UPGRADED_EVENT_SIG} from "./ERC1967Proxy.sol";
// import {LibERC1967ProxyWithImmutableArgs} from "./LibERC1967ProxyWithImmutableArgs.sol";

// import {Test, console} from "forge-std/Test.sol";

// contract Mock {
//     address public constant test = address(0xb0b);
//     bytes32 public constant proxiableUUID = ERC1967_PROXY_STORAGE_SLOT;
// }

// contract TestYul is Test {
//     address bob = address(0xb0b);
//     address alice = address(0xbabe);
//     address tester = address(this);

//     address logic;

//     function setUp() public {
//         Mock mock = new Mock();

//         logic = LibERC1967ProxyWithImmutableArgs.deployProxyWithImmutableArgs(creationCode, immutableArgs);
//     }

//     function test_yul() public {
//         address t = Mock(logic).test();

//         console.logAddress(t);
//         // scrambleMem(0x90, 158);
//         // mstoreBytes(18, hex"290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563b10e2d527612");
//         // mdump(0x80, 5);
//     }
// }

// // // re-run all tests in "./UUPSUpgrade.t.sol"
// // import {TestUUPSUpgrade, LogicV1, LogicV2} from "./UUPSUpgrade.t.sol";

// // contract TestYulUPS is TestUUPSUpgrade {
// //     function deployProxy(address implementation, bytes memory initCalldata) internal override returns (address) {
// //         bytes memory runtimeCode = proxyRuntimeCode();
// //         bytes memory creationCode = proxyCreationCode(address(implementation), runtimeCode, initCalldata);

// //         return deployCode(creationCode);
// //     }
// // }
