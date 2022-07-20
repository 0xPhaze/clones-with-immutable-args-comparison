// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";

import {utils} from "/utils/utils.sol";
import {ProxyTestDeployer} from "./utils/ProxyTestDeployer.sol";

import {LibERC1967ProxyWithImmutableArgs} from "/LibERC1967ProxyWithImmutableArgs.sol";
import {MockUUPSUpgradeWithImmutableArgs as Logic} from "./mocks/MockUUPSUpgradeWithImmutableArgs.sol";

contract TestImmutableArgs is Test {
    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    Logic logic;

    function setUp() public {
        logic = new Logic(1);
    }

    /* ------------- helpers ------------- */

    function setupScrambledCalldataWithArg(
        uint256 arg,
        uint256 offset,
        uint256 argLen
    ) internal pure returns (bytes32[] memory args) {
        // create the "immutable" args 3 * bytes32 array
        args = new bytes32[](3);

        // randomize array
        utils.scrambleMem(args);

        // store argLen-masked arg in encoded calldata location at offset
        utils.mstore(utils.mloc(args) + 32 + offset, bytes32(arg << (256 - 8 * argLen)), argLen);
    }

    function testFuzz_getFullCalldata(bytes memory immutableArgs) public {
        Logic proxy = Logic(
            LibERC1967ProxyWithImmutableArgs.deployProxyWithImmutableArgs(address(logic), "", immutableArgs)
        );

        bytes memory fullCalldata = proxy.getFullCalldata();

        assertEq(
            fullCalldata,
            abi.encodePacked(proxy.getFullCalldata.selector, immutableArgs, uint16(immutableArgs.length))
        );
    }

    function testFuzz_getFullCalldataXtra(bytes memory immutableArgs, bytes memory randomCalldata) public {
        Logic proxy = Logic(
            LibERC1967ProxyWithImmutableArgs.deployProxyWithImmutableArgs(address(logic), "", immutableArgs)
        );

        bytes memory fullCalldata = proxy.getFullCalldataXtra(randomCalldata);

        assertEq(
            fullCalldata,
            abi.encodePacked(
                proxy.getFullCalldataXtra.selector,
                abi.encode(randomCalldata),
                immutableArgs,
                uint16(immutableArgs.length)
            )
        );
    }

    /* ------------- getArg() ------------- */

    /// retrieve an immutable arg hidden at an arbitrary location in scrambled data
    ///
    /// example:
    ///
    /// argLen  = 5
    /// arg     = 0x0000000000000000000000000000000000000000000000000042421337133769
    /// argMask = 0x000000000000000000000000000000000000000000000000000000ffffffffff
    ///
    /// offset  = 12
    ///
    /// memory location of args, mloc(args) = 196
    /// mem dump mdump(mloc(args), 4) shows
    /// 196, 0
    /// 0x0000000000000000000000000000000000000000000000000000000000000003
    /// 196, 32
    /// 0x290decd9548b62a8d60345a91337133769a6bc95484008f6362f93160ef3e563
    /// 196, 64              [12, ^^^^^^^^^^ 12 + 5)
    /// 0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6
    /// 196, 96
    /// 0x405787fa12a823e0f2b7631cc41b3ba8828b3321ca811111fa75cd3aa3bb5ace

    function testFuzz_getArg(
        uint256 arg,
        uint256 offset,
        uint256 argLen,
        bytes memory randomCalldata
    ) public {
        // restrict argLen to [0, 32] bytes
        argLen = argLen % (32 + 1);

        // restrict offset to [0, 3 * 32 - argLen] bytes, max offset
        offset = offset % (32 * 3 - argLen + 1);

        // mask arg to argLen for comparison
        unchecked {
            arg = arg & ((1 << (8 * argLen)) - 1); // keeping the most significant bits
        }

        // place argLen-masked arg in 3 * bytes32 encoded scrambled calldata at offset
        bytes32[] memory args = setupScrambledCalldataWithArg(arg, offset, argLen);

        // test for bytecode proxy
        Logic proxy = Logic(
            LibERC1967ProxyWithImmutableArgs.deployProxyWithImmutableArgs(
                address(logic),
                "",
                abi.encode(args[0], args[1], args[2])
            )
        );

        // sprinkle in some random calldata to make sure immutable args and calldata are independent
        (bytes memory randomCalldataReturned, uint256 proxyArg) = proxy.getArgRandomCalldata(
            randomCalldata,
            offset,
            argLen
        );

        assertEq(proxyArg, arg);
        assertEq(randomCalldataReturned, randomCalldata);
        assertEq(proxy.getImmutableArgsLen(), 96);

        // deploy with all 3 * bytes32 fixed args
        proxy = Logic(
            LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1], args[2])
        );

        (randomCalldataReturned, proxyArg) = proxy.getArgRandomCalldata(randomCalldata, offset, argLen);

        assertEq(proxyArg, arg);
        assertEq(randomCalldataReturned, randomCalldata);
        assertEq(proxy.getImmutableArgsLen(), 96);

        // if argument is located in the first 2 arg slots
        // make sure arg can be recovered by proxy with 2 immutable args
        if (offset <= 32 * 2 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1]));

            (randomCalldataReturned, proxyArg) = proxy.getArgRandomCalldata(randomCalldata, offset, argLen);

            assertEq(proxyArg, arg);
            assertEq(randomCalldataReturned, randomCalldata);
            assertEq(proxy.getImmutableArgsLen(), 64);
        }

        // if argument is located in the first arg slot
        // make sure arg can be recovered by proxy with 1 immutable arg
        if (offset <= 32 * 1 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0]));

            (randomCalldataReturned, proxyArg) = proxy.getArgRandomCalldata(randomCalldata, offset, argLen);

            assertEq(proxyArg, arg);
            assertEq(randomCalldataReturned, randomCalldata);
            assertEq(proxy.getImmutableArgsLen(), 32);
        }
    }

    /// test immutable uint8 arg stored at arbitrary location
    function testFuzz_getArgUint8(uint8 arg, uint256 offset) public {
        uint256 argLen = 1;

        offset = offset % (32 * 3 - argLen + 1);

        bytes32[] memory args = setupScrambledCalldataWithArg(arg, offset, argLen);

        Logic proxy = Logic(
            LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1], args[2])
        );

        assertEq(proxy.getArgUint8(offset), arg);

        if (offset <= 32 * 2 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1]));

            assertEq(proxy.getArgUint8(offset), arg);
        }

        if (offset <= 32 * 1 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0]));

            assertEq(proxy.getArgUint8(offset), arg);
        }
    }

    /// test immutable uint40 arg stored at arbitrary location
    function testFuzz_getArgUint40(uint40 arg, uint256 offset) public {
        uint256 argLen = 5;

        offset = offset % (32 * 3 - argLen + 1);

        bytes32[] memory args = setupScrambledCalldataWithArg(arg, offset, argLen);

        Logic proxy = Logic(
            LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1], args[2])
        );

        assertEq(proxy.getArgUint40(offset), arg);

        if (offset <= 32 * 2 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1]));

            assertEq(proxy.getArgUint40(offset), arg);
        }

        if (offset <= 32 * 1 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0]));

            assertEq(proxy.getArgUint40(offset), arg);
        }
    }

    /// test immutable uint64 arg stored at arbitrary location
    function testFuzz_getArgUint64(uint64 arg, uint256 offset) public {
        uint256 argLen = 8;

        offset = offset % (32 * 3 - argLen + 1);

        bytes32[] memory args = setupScrambledCalldataWithArg(arg, offset, argLen);

        Logic proxy = Logic(
            LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1], args[2])
        );

        assertEq(proxy.getArgUint64(offset), arg);

        if (offset <= 32 * 2 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1]));

            assertEq(proxy.getArgUint64(offset), arg);
        }

        if (offset <= 32 * 1 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0]));

            assertEq(proxy.getArgUint64(offset), arg);
        }
    }

    /// test immutable uint128 arg stored at arbitrary location
    function testFuzz_getArgUint128(uint128 arg, uint256 offset) public {
        uint256 argLen = 16;

        offset = offset % (32 * 3 - argLen + 1);

        bytes32[] memory args = setupScrambledCalldataWithArg(arg, offset, argLen);

        Logic proxy = Logic(
            LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1], args[2])
        );

        assertEq(proxy.getArgUint128(offset), arg);

        if (offset <= 32 * 2 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1]));

            assertEq(proxy.getArgUint128(offset), arg);
        }

        if (offset <= 32 * 1 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0]));

            assertEq(proxy.getArgUint128(offset), arg);
        }
    }

    /// test immutable uint256 arg stored at arbitrary location
    function testFuzz_getArgUint256(uint256 arg, uint256 offset) public {
        uint256 argLen = 32;

        offset = offset % (32 * 3 - argLen + 1);

        bytes32[] memory args = setupScrambledCalldataWithArg(arg, offset, argLen);

        Logic proxy = Logic(
            LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1], args[2])
        );

        assertEq(proxy.getArgUint256(offset), arg);

        if (offset <= 32 * 2 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1]));

            assertEq(proxy.getArgUint256(offset), arg);
        }

        if (offset <= 32 * 1 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0]));

            assertEq(proxy.getArgUint256(offset), arg);
        }
    }

    /// test immutable bytes32 arg stored at arbitrary location
    function testFuzz_getArgBytes32(bytes32 arg, uint256 offset) public {
        uint256 argLen = 32;

        offset = offset % (32 * 3 - argLen + 1);

        bytes32[] memory args = setupScrambledCalldataWithArg(uint256(arg), offset, argLen);

        Logic proxy = Logic(
            LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1], args[2])
        );

        assertEq(proxy.getArgBytes32(offset), arg);

        if (offset <= 32 * 2 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1]));

            assertEq(proxy.getArgBytes32(offset), arg);
        }

        if (offset <= 32 * 1 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0]));

            assertEq(proxy.getArgBytes32(offset), arg);
        }
    }

    /// test immutable address arg stored at arbitrary location
    function testFuzz_getArgAddress(address addr, uint256 offset) public {
        uint256 argLen = 20;

        offset = offset % (32 * 3 - argLen + 1);

        bytes32[] memory args = setupScrambledCalldataWithArg(uint256(uint160(addr)), offset, argLen);

        Logic proxy = Logic(
            LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1], args[2])
        );

        assertEq(proxy.getArgAddress(offset), addr);

        if (offset <= 32 * 2 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0], args[1]));

            assertEq(proxy.getArgAddress(offset), addr);
        }

        if (offset <= 32 * 1 - argLen) {
            proxy = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", args[0]));

            assertEq(proxy.getArgAddress(offset), addr);
        }
    }

    /// test immutable args
    function testFuzz_args(
        bytes32 arg1,
        bytes32 arg2,
        bytes32 arg3
    ) public {
        Logic proxy1 = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", arg1));
        Logic proxy2 = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", arg1, arg2));
        Logic proxy3 = Logic(
            LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", arg1, arg2, arg3)
        );

        assertEq(proxy1.arg1(), arg1);

        assertEq(proxy2.arg1(), arg1);
        assertEq(proxy2.arg2(), arg2);

        assertEq(proxy3.arg1(), arg1);
        assertEq(proxy3.arg2(), arg2);
        assertEq(proxy3.arg3(), arg3);
    }

    /// make sure normal function args are still valid for bytesFn
    function testFuzz_bytesFn(
        bytes calldata data,
        bytes32 arg1,
        bytes32 arg2,
        bytes32 arg3
    ) public {
        // bytes memory initCalldata = abi.encode(address(logic), "");

        Logic proxy1 = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", arg1));
        Logic proxy2 = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", arg1, arg2));
        Logic proxy3 = Logic(
            LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", arg1, arg2, arg3)
        );

        bytes32 arg1_;
        bytes32 arg2_;
        bytes32 arg3_;
        bytes memory data_;

        (data_, arg1_, , ) = proxy1.bytesFn(data);

        assertEq(arg1_, arg1);
        assertEq(keccak256(data_), keccak256(data));

        (data_, arg1_, arg2_, ) = proxy2.bytesFn(data);

        assertEq(arg1_, arg1);
        assertEq(arg2_, arg2);
        assertEq(keccak256(data_), keccak256(data));

        (data_, arg1_, arg2_, arg3_) = proxy3.bytesFn(data);

        assertEq(arg1_, arg1);
        assertEq(arg2_, arg2);
        assertEq(arg3_, arg3);
        assertEq(keccak256(data_), keccak256(data));
    }

    /// make sure normal function args are still valid for bytes32Fn
    function testFuzz_bytes32Fn(
        bytes32 fnArg1,
        bytes32 fnArg2,
        bytes32 fnArg3,
        bytes32 arg1,
        bytes32 arg2,
        bytes32 arg3
    ) public {
        {
            Logic proxy1 = Logic(LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", arg1));

            (bytes32 fnArg1_, bytes32 fnArg2_, bytes32 fnArg3_, bytes32 arg1_, , ) = proxy1.bytes32Fn(
                fnArg1,
                fnArg2,
                fnArg3
            );

            assertEq(fnArg1_, fnArg1);
            assertEq(fnArg2_, fnArg2);
            assertEq(fnArg3_, fnArg3);
            assertEq(arg1_, arg1);
        }

        {
            Logic proxy2 = Logic(
                LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", arg1, arg2)
            );

            (bytes32 fnArg1_, bytes32 fnArg2_, bytes32 fnArg3_, bytes32 arg1_, bytes32 arg2_, ) = proxy2.bytes32Fn(
                fnArg1,
                fnArg2,
                fnArg3
            );

            assertEq(fnArg1_, fnArg1);
            assertEq(fnArg2_, fnArg2);
            assertEq(fnArg3_, fnArg3);
            assertEq(arg1_, arg1);
            assertEq(arg2_, arg2);
        }

        {
            Logic proxy3 = Logic(
                LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(address(logic), "", arg1, arg2, arg3)
            );

            (bytes32 fnArg1_, bytes32 fnArg2_, bytes32 fnArg3_, bytes32 arg1_, bytes32 arg2_, bytes32 arg3_) = proxy3
                .bytes32Fn(fnArg1, fnArg2, fnArg3);

            assertEq(fnArg1_, fnArg1);
            assertEq(fnArg2_, fnArg2);
            assertEq(fnArg3_, fnArg3);
            assertEq(arg1_, arg1);
            assertEq(arg2_, arg2);
            assertEq(arg3_, arg3);
        }
    }
}

// ---------------------------------------------------------------------------------------
// re-run all tests from "./UUPSUpgrade.t.sol" for all proxy types
// ---------------------------------------------------------------------------------------

import {TestUUPSUpgrade, LogicV1, LogicV2} from "./UUPSUpgrade.t.sol";

contract TestUUPSUpgradeWithImmutableArgs is TestUUPSUpgrade {
    function deployProxyAndCall(address implementation, bytes memory initCalldata) internal override returns (address) {
        return
            LibERC1967ProxyWithImmutableArgs.deployProxyWithImmutableArgs(
                implementation,
                initCalldata,
                abi.encode(keccak256("arg1"), keccak256("arg2"), keccak256("arg3"))
            );
    }
}

contract TestUUPSUpgradeWith3ImmutableArgs is TestUUPSUpgrade {
    function deployProxyAndCall(address implementation, bytes memory initCalldata) internal override returns (address) {
        return
            LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(
                implementation,
                initCalldata,
                keccak256("arg1"),
                keccak256("arg2"),
                keccak256("arg3")
            );
    }
}

contract TestUUPSUpgradeWith2ImmutableArgs is TestUUPSUpgrade {
    function deployProxyAndCall(address implementation, bytes memory initCalldata) internal override returns (address) {
        return
            LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(
                implementation,
                initCalldata,
                keccak256("arg1"),
                keccak256("arg2")
            );
    }
}

contract TestUUPSUpgradeWith1ImmutableArgs is TestUUPSUpgrade {
    function deployProxyAndCall(address implementation, bytes memory initCalldata) internal override returns (address) {
        return LibERC1967ProxyWithImmutableArgs.deployProxyVerifiable(implementation, initCalldata, keccak256("arg1"));
    }
}

// ---------------------------------------------------------------------------------------
// re-run all tests from "./ERC1967.t.sol" for all proxy types
// - these tests need to be run from a `Deployer` contract,
//   so that forge can catch the reverts on external calls
// ---------------------------------------------------------------------------------------

import {TestERC1967} from "./ERC1967.t.sol";

contract TestERC1967WithImmutableArgs is TestERC1967 {
    ProxyTestDeployer deployer;

    function setUp() public override {
        super.setUp();
        deployer = new ProxyTestDeployer();
    }

    function deployProxyAndCall(address implementation, bytes memory initCalldata) internal override returns (address) {
        return
            deployer.deployProxyWithImmutableArgs(
                implementation,
                initCalldata,
                abi.encode(keccak256("arg1"), keccak256("arg2"), keccak256("arg3"))
            );
    }
}

contract TestERC1967With3ImmutableArgs is TestERC1967 {
    ProxyTestDeployer deployer;

    function setUp() public override {
        super.setUp();
        deployer = new ProxyTestDeployer();
    }

    function deployProxyAndCall(address implementation, bytes memory initCalldata) internal override returns (address) {
        return
            deployer.deployProxyVerifiable(
                implementation,
                initCalldata,
                keccak256("arg1"),
                keccak256("arg2"),
                keccak256("arg3")
            );
    }
}

contract TestERC1967With2ImmutableArgs is TestERC1967 {
    ProxyTestDeployer deployer;

    function setUp() public override {
        super.setUp();
        deployer = new ProxyTestDeployer();
    }

    function deployProxyAndCall(address implementation, bytes memory initCalldata) internal override returns (address) {
        return deployer.deployProxyVerifiable(implementation, initCalldata, keccak256("arg1"), keccak256("arg2"));
    }
}

contract TestERC1967With1ImmutableArgs is TestERC1967 {
    ProxyTestDeployer deployer;

    function setUp() public override {
        super.setUp();
        deployer = new ProxyTestDeployer();
    }

    function deployProxyAndCall(address implementation, bytes memory initCalldata) internal override returns (address) {
        return deployer.deployProxyVerifiable(implementation, initCalldata, keccak256("arg1"));
    }
}
