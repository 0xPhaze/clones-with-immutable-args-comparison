// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {MockUUPSUpgrade} from "./mocks/MockUUPSUpgrade.sol";

import "/ERC1967Proxy.sol";

// ---------------------------------------------------------------------
// Mock Logic
// ---------------------------------------------------------------------

error RevertOnInit();

contract LogicV1 is MockUUPSUpgrade(1) {
    uint256 public data = 0x1337;
    uint256 public initializedCount;
    bool public callLogged;

    function init() public {
        ++initializedCount;
    }

    function fn() public pure returns (uint256) {
        return 1337;
    }

    function setData(uint256 newData) public {
        data = newData;
    }

    fallback() external {
        callLogged = true;
    }
}

contract LogicV2 is MockUUPSUpgrade(2) {
    address public data = address(0x42);

    function initReverts() public pure {
        revert RevertOnInit();
    }

    function fn() public pure returns (uint256) {
        return 6969;
    }

    function fn2() public pure returns (uint256) {
        return 3141;
    }

    function initRevertsCustomMessage(string memory message) public pure {
        require(false, message);
    }
}

contract LogicNonexistentUUID {}

contract LogicInvalidUUID {
    bytes32 public proxiableUUID = 0x0000000000000000000000000000000000000000000000000000000000001234;
}

// ---------------------------------------------------------------------
// UUPSUpgrade Tests
// ---------------------------------------------------------------------

contract TestUUPSUpgrade is Test {
    event Upgraded(address indexed implementation);

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    address proxy;
    LogicV1 logicV1;
    LogicV2 logicV2;

    function deployProxyAndCall(address implementation, bytes memory initCalldata) internal virtual returns (address) {
        return address(new ERC1967Proxy(address(implementation), initCalldata));
    }

    function setUp() public virtual {
        logicV1 = new LogicV1();
        logicV2 = new LogicV2();

        proxy = deployProxyAndCall(address(logicV1), "");
    }

    /* ------------- setUp() ------------- */

    function test_setUp() public {
        assertEq(logicV1.version(), 1);
        assertEq(logicV2.version(), 2);
        assertEq(LogicV1(proxy).version(), 1);

        assertEq(logicV1.fn(), 1337);
        assertEq(logicV2.fn(), 6969);
        assertEq(logicV2.fn2(), 3141);
        assertEq(LogicV1(proxy).fn(), 1337);

        assertEq(logicV1.data(), 0x1337);
        assertEq(logicV2.data(), address(0x42));
        assertEq(LogicV1(proxy).data(), 0);

        assertEq(LogicV1(proxy).callLogged(), false);
        assertEq(LogicV1(proxy).initializedCount(), 0);
    }

    /* ------------- upgradeToAndCall() ------------- */

    /// expect implementation logic to change on upgrade
    function test_upgradeToAndCall_logic() public {
        assertEq(LogicV1(proxy).data(), 0);

        // proxy can call v1's setData
        LogicV1(proxy).setData(0x3333);

        assertEq(LogicV1(proxy).data(), 0x3333); // proxy's data now has changed
        assertEq(logicV1.data(), 0x1337); // implementation's data remains unchanged

        // -> upgrade to v2
        LogicV1(proxy).upgradeToAndCall(address(logicV2), "");

        // test v2 functions
        assertEq(LogicV2(proxy).fn(), 6969);
        assertEq(LogicV2(proxy).fn2(), 3141);

        // make sure data remains unchanged (though returned as address now)
        assertEq(LogicV2(proxy).data(), address(0x3333));

        // only available under v1 logic
        vm.expectRevert();
        LogicV1(proxy).setData(0x456);

        // <- upgrade back to v1
        LogicV2(proxy).upgradeToAndCall(address(logicV1), "");

        // v1's setData works again
        LogicV1(proxy).setData(0x6666);

        assertEq(LogicV1(proxy).data(), 0x6666);

        // only available under v2 logic
        vm.expectRevert();
        LogicV2(proxy).fn2();
    }

    /// expect implementation to be stored correctly
    function test_upgradeToAndCall_implementation() public {
        LogicV1(proxy).upgradeToAndCall(address(logicV2), "");

        MockUUPSUpgrade(proxy).scrambleStorage(0, 100);

        assertEq(LogicV1(proxy).implementation(), address(logicV2));
        assertEq(vm.load(proxy, ERC1967_PROXY_STORAGE_SLOT), bytes32(uint256(uint160(address(logicV2)))));
    }

    /// expect Upgraded(address) to be emitted
    function test_upgradeToAndCall_emit() public {
        vm.expectEmit(true, false, false, false, proxy);

        emit Upgraded(address(logicV2));

        LogicV1(proxy).upgradeToAndCall(address(logicV2), "");

        vm.expectEmit(true, false, false, false, proxy);

        emit Upgraded(address(logicV1));

        LogicV2(proxy).upgradeToAndCall(address(logicV1), "");
    }

    /// expect upgradeToAndCall to actually call the function
    function test_upgradeToAndCall_init() public {
        assertEq(LogicV1(proxy).initializedCount(), 0);

        LogicV1(proxy).upgradeToAndCall(address(logicV1), abi.encodePacked(LogicV1.init.selector));

        assertEq(LogicV1(proxy).initializedCount(), 1);

        LogicV1(proxy).upgradeToAndCall(address(logicV1), abi.encodePacked(LogicV1.init.selector));

        assertEq(LogicV1(proxy).initializedCount(), 2);
    }

    /// upgrade and call a nonexistent init function
    function test_upgradeToAndCall_fail_fallback() public {
        vm.expectRevert();

        LogicV1(proxy).upgradeToAndCall(address(logicV2), "abcd");
    }

    /// upgrade to v2 and call a reverting init function
    /// expect revert reason to bubble up
    function test_upgradeToAndCall_fail_RevertOnInit() public {
        vm.expectRevert(RevertOnInit.selector);

        LogicV1(proxy).upgradeToAndCall(address(logicV2), abi.encodePacked(LogicV2.initReverts.selector));
    }

    /// call a reverting function during upgrade
    /// make sure the error is returned
    function testFuzz_upgradeToAndCall_fail_initRevertsCustomMessage(string memory message) public {
        vm.expectRevert(bytes(message));

        bytes memory initCalldata = abi.encodeWithSelector(LogicV2.initRevertsCustomMessage.selector, message);

        LogicV1(proxy).upgradeToAndCall(address(logicV2), initCalldata);
    }

    /// upgrade to an invalid address (EOA)
    function testFuzz_upgradeToAndCall_fail_NotAContract(bytes memory initCalldata) public {
        vm.expectRevert(NotAContract.selector);

        LogicV1(proxy).upgradeToAndCall(bob, initCalldata);
    }

    /// upgrade to contract with an invalid uuid
    function testFuzz_upgradeToAndCall_fail_InvalidUUID(bytes memory initCalldata) public {
        address logic = address(new LogicInvalidUUID());

        vm.expectRevert(InvalidUUID.selector);

        LogicV1(proxy).upgradeToAndCall(logic, initCalldata);
    }

    /// upgrade to a contract that doesn't implement proxiableUUID
    function testFuzz_upgradeToAndCall_fail_NonexistentUUID(bytes memory initCalldata) public {
        address logic = address(new LogicNonexistentUUID());

        vm.expectRevert();

        LogicV1(proxy).upgradeToAndCall(logic, initCalldata);
    }

    // /* ------------- gas ------------- */

    // function testGas_deploy() public {
    //     deployProxyAndCall(address(logicV1), "");
    // }

    // function testGas_upgradeTo() public {
    //     LogicV1(proxy).upgradeToAndCall(address(logicV2), "");
    // }

    // function testGas_upgradeToAndCall() public {
    //     LogicV1(proxy).upgradeToAndCall(address(logicV2), abi.encodePacked(LogicV2.fn.selector));
    // }

    // function testGas_version() public view {
    //     LogicV1(proxy).version();
    // }
}
