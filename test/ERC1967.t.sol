// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {MockUUPSUpgrade} from "./mocks/MockUUPSUpgrade.sol";

import "/ERC1967Proxy.sol";

// ---------------------------------------------------------------------
// Mock Logic
// ---------------------------------------------------------------------

error RevertOnInit();

contract Logic is MockUUPSUpgrade(1) {
    uint256 public initializedCount;

    function init() public {
        ++initializedCount;
    }

    function initReverts() public pure {
        revert RevertOnInit();
    }

    function initRevertsCustomMessage(string memory message) public pure {
        require(false, message);
    }
}

contract LogicNonexistentUUID {}

contract LogicInvalidUUID {
    bytes32 public proxiableUUID = bytes32(0x1234);
}

// ---------------------------------------------------------------------
// ERC1967 Tests
// ---------------------------------------------------------------------

contract TestERC1967 is Test {
    event Upgraded(address indexed implementation);

    Logic logic;
    address proxy;

    function deployProxyAndCall(address implementation, bytes memory initCalldata) internal virtual returns (address) {
        return address(new ERC1967Proxy(address(implementation), initCalldata));
    }

    function setUp() public virtual {
        logic = new Logic();
    }

    function test_setUp() public virtual {
        assertEq(UPGRADED_EVENT_SIG, keccak256("Upgraded(address)"));
        assertEq(ERC1967_PROXY_STORAGE_SLOT, bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));
    }

    /* ------------- deployProxyAndCall() ------------- */

    /// expect implementation to be stored correctly
    function test_deployProxyAndCall_implementation() public {
        proxy = deployProxyAndCall(address(logic), "");

        // make sure that implementation is not
        // located in sequential storage slot
        MockUUPSUpgrade(proxy).scrambleStorage(0, 100);

        assertEq(MockUUPSUpgrade(proxy).implementation(), address(logic));
        assertEq(vm.load(proxy, ERC1967_PROXY_STORAGE_SLOT), bytes32(uint256(uint160(address(logic)))));
    }

    /// expect Upgraded(address) to be emitted
    function test_deployProxyAndCall_emit() public {
        vm.expectEmit(true, false, false, false);

        emit Upgraded(address(logic));

        proxy = deployProxyAndCall(address(logic), "");
    }

    /// expect proxy to call `init` during deployment
    function test_deployProxyAndCall_init() public {
        proxy = deployProxyAndCall(address(logic), abi.encodePacked(Logic.init.selector));

        assertEq(Logic(proxy).initializedCount(), 1);
    }

    /// call a nonexistent init function
    function test_deployProxyAndCall_fail_fallback() public {
        vm.expectRevert();

        proxy = deployProxyAndCall(address(logic), abi.encodePacked("abcd"));
    }

    /// deploy and upgrade to an invalid address (EOA)
    function test_deployProxyAndCall_fail_NotAContract(bytes memory initCalldata) public {
        vm.expectRevert(NotAContract.selector);

        proxy = deployProxyAndCall(address(0xb0b), initCalldata);
    }

    /// deploy and upgrade to contract with an invalid uuid
    function test_deployProxyAndCall_fail_InvalidUUID(bytes memory initCalldata) public {
        address logic2 = address(new LogicInvalidUUID());

        vm.expectRevert(InvalidUUID.selector);

        proxy = deployProxyAndCall(address(logic2), initCalldata);
    }

    /// deploy and upgrade to a contract that doesn't implement proxiableUUID
    /// this one reverts differently depending on proxy..
    function test_deployProxyAndCall_fail_NonexistentUUID(bytes memory initCalldata) public {
        address logic2 = address(new LogicNonexistentUUID());

        vm.expectRevert();

        proxy = deployProxyAndCall(address(logic2), initCalldata);
    }

    /// note: making all of these testFail, because
    /// retrieving a custom error during contract deployment
    /// is too messy, since it doesn't work by default
    /// (returndatasize() is always 0).
    /// I had tried encoding it in the deployed code
    /// using the convention that if the first byte is 00
    /// then the rest would be the revert message
    /// and tested it out for the bytecode proxy (tests pass)

    /// call a reverting init function
    function testFail_deployProxyAndCall_fail_RevertOnInit() public {
        // vm.expectRevert(RevertOnInit.selector);

        proxy = deployProxyAndCall(address(logic), abi.encodePacked(Logic.initReverts.selector));
    }

    /// call a reverting function during deployment
    /// make sure the error is returned
    function testFail_deployProxyAndCall_fail_initRevertsCustomMessage(bytes memory message) public {
        // vm.expectRevert(message);

        bytes memory initCalldata = abi.encodeWithSelector(Logic.initRevertsCustomMessage.selector, message);

        proxy = deployProxyAndCall(address(logic), initCalldata);
    }
}
