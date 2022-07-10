// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967VersionedUDS.sol";

import {MockVRFCoordinatorV2} from "./mocks/MockVRFCoordinator.sol";

import "../lib/ArrayUtils.sol";
import "../lib/PackedMap.sol";
import "../GangWar.sol";

contract TestGangWar is Test {
    using ArrayUtils for *;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    MockVRFCoordinatorV2 coordinator = new MockVRFCoordinatorV2();
    GangWar impl = new GangWar(address(coordinator), 0, 0, 0, 0);
    GangWar game;
    MockERC721 gmc;

    // bytes constant ROLE = hex'436c6f776e004d6167696369616e004a7567676c657200547261696e657200506572666f726d6572';

    function setUp() public {
        gmc = new MockERC721("GMC", "GMC");

        Gang[] memory gangs = new Gang[](21);
        for (uint256 i; i < 21; i++) gangs[i] = Gang(i % 3);
        // for (uint256 i; i < 21; i++) gangs[i] = Gang((i % 3) + 1);

        uint256[] memory yields = new uint256[](21);
        for (uint256 i; i < 21; i++) yields[i] = 100 + (i / 3);

        address[] memory gangTokens = new address[](3);
        gangTokens[0] = address(new MockERC20("Token", "", 18));
        gangTokens[1] = address(new MockERC20("Token", "", 18));
        gangTokens[2] = address(new MockERC20("Token", "", 18));

        bytes memory initCall = abi.encodeWithSelector(game.init.selector, address(gmc), gangTokens, gangs, yields);
        game = GangWar(address(new ERC1967Proxy(address(impl), initCall)));

        bool[21][21] memory connections;
        connections[0][1] = true;
        connections[1][2] = true;
        connections[2][3] = true;
        connections[0][3] = true;
        connections[3][4] = true;
        connections[6][7] = true;
        game.setDistrictConnections(PackedMap.encode(connections));

        // uint256[] memory gDistrictIds = [1, 2, 3, 4, 5, 6].toMemory();
        // uint256[] memory gangsUint256 = [1, 2, 3, 1, 2, 3].toMemory();
        // game.setDistrictsInitialOwnership(gangs);

        gmc.mint(bob, 1001); // Yakuza Baron
        gmc.mint(bob, 1002); // Cartel Baron
        gmc.mint(bob, 1003); // Cyberp Baron
        gmc.mint(bob, 1004); // Yakuza Baron

        gmc.mint(alice, 1); // Yakuza Gangster
        gmc.mint(alice, 2); // Cartel Gangster
        gmc.mint(alice, 3); // Cyberp Gangster
        gmc.mint(alice, 4); // Yakuza Gangster

        vm.warp(100000);
    }

    function assertEq(Gang a, Gang b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(PLAYER_STATE a, PLAYER_STATE b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(DISTRICT_STATE a, DISTRICT_STATE b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(uint256[] memory a, uint256[] memory b) internal {
        assertEq(a.length, b.length);
        for (uint256 i; i < a.length; ++i) assertEq(a[i], b[i]);
    }

    function test_setUp() public {
        uint256 connections = game.getDistrictConnections();
        assertTrue(PackedMap.isConnecting(connections, 0, 1));
        assertTrue(PackedMap.isConnecting(connections, 1, 2));
        assertTrue(PackedMap.isConnecting(connections, 2, 3));
        assertTrue(PackedMap.isConnecting(connections, 3, 4));
        assertTrue(PackedMap.isConnecting(connections, 6, 7));

        for (uint256 i; i < 21; i++) {
            District memory district = game.getDistrict(i);

            assertEq(district.occupants, Gang(i % 3));
            assertEq(district.roundId, 1);
            assertEq(district.attackDeclarationTime, 0);
            assertEq(district.baronAttackId, 0);
            assertEq(district.baronDefenseId, 0);
            assertEq(district.lastUpkeepTime, 0);
            assertEq(district.lockupTime, 0);
        }

        assertEq(game.gangOf(1), Gang.YAKUZA);
        assertEq(game.gangOf(1001), Gang.YAKUZA);

        assertEq(game.getGangster(1).state, PLAYER_STATE.IDLE);
        assertEq(game.getGangster(1001).state, PLAYER_STATE.IDLE);

        assertEq(game.getConstants().TIME_TRUCE, 100);
        assertEq(game.getConstants().TIME_GANG_WAR, 100);
        assertEq(game.getConstants().TIME_LOCKUP, 100);
        assertEq(game.getConstants().TIME_RECOVERY, 100);
        assertEq(game.getConstants().TIME_REINFORCEMENTS, 100);

        assertTrue(game.getConstants().DEFENSE_FAVOR_LIM > 0);
        assertTrue(game.getConstants().BARON_DEFENSE_FORCE > 0);
        assertTrue(game.getConstants().ATTACK_FAVOR > 0);
        assertTrue(game.getConstants().DEFENSE_FAVOR > 0);

        // (uint256 yieldYakuza, uint256 yieldCartel, uint256 yieldCyberpunk) =
        // FIX
        // uint256[3][3] memory yields = game.getYield();

        // assertTrue(yields[0][0] > 0);
        // assertEq(yields[0][0], yields[1][1]);
        // assertEq(yields[0][0], yields[2][2]);
    }

    /* ------------- districtState() ------------- */

    function test_districtState() public {
        DISTRICT_STATE state;
        District memory district;

        (district, state) = game.getDistrictAndState(1);
        assertEq(state, DISTRICT_STATE.IDLE);

        // REINFORCEMENT
        vm.prank(bob);
        game.baronDeclareAttack(0, 1, 1001);

        (district, state) = game.getDistrictAndState(1);
        assertEq(state, DISTRICT_STATE.REINFORCEMENT);

        // GANG_WAR
        skip(game.getConstants().TIME_REINFORCEMENTS);

        (district, state) = game.getDistrictAndState(1);
        assertEq(state, DISTRICT_STATE.GANG_WAR);

        // POST_GANG_WAR
        skip(game.getConstants().TIME_GANG_WAR);

        (district, state) = game.getDistrictAndState(1);
        assertEq(state, DISTRICT_STATE.POST_GANG_WAR);

        // skipping time won't change phase
        skip(10000000000);

        (district, state) = game.getDistrictAndState(1);
        assertEq(state, DISTRICT_STATE.POST_GANG_WAR);

        // TRUCE - perform upkeep
        (, bytes memory data) = game.checkUpkeep("");
        game.performUpkeep(data);

        uint256 requestId = coordinator.requestIdCounter();
        vm.prank(address(coordinator));
        game.rawFulfillRandomWords(requestId, [1234].toMemory());

        (district, state) = game.getDistrictAndState(1);
        assertEq(state, DISTRICT_STATE.TRUCE);

        // IDLE
        skip(game.getConstants().TIME_TRUCE);

        (district, state) = game.getDistrictAndState(1);
        assertEq(state, DISTRICT_STATE.IDLE);
    }

    /* ------------- baronDeclareAttack() ------------- */

    function test_baronDeclareAttack() public {
        vm.prank(bob);
        game.baronDeclareAttack(0, 1, 1001);

        District memory district = game.getDistrict(1);

        assertEq(district.attackers, Gang.YAKUZA);
        assertEq(district.attackDeclarationTime, block.timestamp);
        assertEq(district.baronAttackId, 1001);

        GangsterView memory baron = game.getGangster(1001);

        assertEq(baron.state, PLAYER_STATE.ATTACK);
        assertEq(baron.location, 1);
        assertEq(baron.roundId, game.getDistrict(1).roundId);
        assertEq(uint256(baron.stateCountdown), game.getConstants().TIME_REINFORCEMENTS);

        // skip after reinforcement time
        skip(game.getConstants().TIME_REINFORCEMENTS);

        baron = game.getGangster(1001);

        assertEq(baron.state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(baron.stateCountdown, 100);
    }

    /// verify baron state after attacking 2nd district

    /// verify baron can attack 2nd district

    /// attack the same district twice with different baron

    /// attack the same district twice
    function test_baronDeclareAttack_fail_BaronAttackAlreadyDeclared() public {
        vm.prank(bob);
        game.baronDeclareAttack(0, 1, 1001);

        vm.expectRevert(BaronAttackAlreadyDeclared.selector);

        vm.prank(bob);
        game.baronDeclareAttack(0, 1, 1001);
    }

    /// baron already in an attack
    function test_baronDeclareAttack_fail_BaronInactionable() public {
        vm.prank(bob);
        game.baronDeclareAttack(0, 1, 1001);

        vm.expectRevert(BaronInactionable.selector);

        vm.prank(bob);
        game.baronDeclareAttack(3, 4, 1001);
    }

    /* ------------- joinGangAttack() ------------- */

    function test_joinGangAttack() public {
        vm.prank(bob);
        game.baronDeclareAttack(0, 1, 1001);

        vm.prank(alice);
        game.joinGangAttack(0, 1, [1].toMemory());

        GangsterView memory gangster = game.getGangster(1);

        assertEq(gangster.roundId, 1);
        assertEq(gangster.location, 1);
        assertEq(gangster.state, PLAYER_STATE.ATTACK);
        assertEq(game.getDistrict(2).roundId, 1);
        assertEq(uint256(gangster.stateCountdown), game.getConstants().TIME_REINFORCEMENTS);
    }

    /// Join in another attack in different district
    function test_joinGangAttack2() public {
        // -------- perform first attack
        vm.prank(bob);
        game.baronDeclareAttack(0, 1, 1001);

        vm.prank(alice);
        game.joinGangAttack(0, 1, [1].toMemory());

        skip(5000000);

        // -------- perform upkeep
        (, bytes memory data) = game.checkUpkeep("");
        game.performUpkeep(data);

        // -------- request outcome
        uint256 requestId = coordinator.requestIdCounter();
        vm.prank(address(coordinator));
        game.rawFulfillRandomWords(requestId, [1234].toMemory());

        skip(5000000);

        // -------- perform second attack
        vm.prank(bob);
        game.baronDeclareAttack(3, 4, 1001);

        vm.prank(alice);
        game.joinGangAttack(3, 4, [1].toMemory());

        GangsterView memory gangster = game.getGangster(1);

        assertEq(gangster.roundId, 1);
        assertEq(gangster.location, 4);
        assertEq(gangster.state, PLAYER_STATE.ATTACK);
        assertEq(game.getDistrict(4).roundId, 1);
        assertEq(uint256(gangster.stateCountdown), game.getConstants().TIME_REINFORCEMENTS);
    }

    /// Baron must lead an attack
    function test_joinGangAttack_fail_BaronMustDeclareInitialAttack() public {
        vm.expectRevert(BaronMustDeclareInitialAttack.selector);

        vm.prank(alice);
        game.joinGangAttack(0, 1, [1].toMemory());
    }

    /// Call for NFT not owned by caller
    function test_joinGangAttack_fail_CallerNotOwner() public {
        vm.prank(bob);
        game.baronDeclareAttack(0, 1, 1001);

        vm.expectRevert(CallerNotOwner.selector);

        vm.prank(bob);
        game.joinGangAttack(0, 1, [1].toMemory());
    }

    /// Invalid connecting district
    function test_joinGangAttack_fail_InvalidConnectingDistrict() public {
        vm.prank(bob);
        game.baronDeclareAttack(0, 1, 1001);

        vm.expectRevert(InvalidConnectingDistrict.selector);

        vm.prank(alice);
        game.joinGangAttack(4, 2, [1].toMemory());
    }

    /// Invalid connecting district (not owned by attacker)
    function test_joinGangAttack_fail_InvalidConnectingDistrict2() public {
        vm.prank(bob);
        game.baronDeclareAttack(0, 1, 1001);

        vm.expectRevert(InvalidConnectingDistrict.selector);

        vm.prank(alice);
        game.joinGangAttack(2, 2, [1].toMemory());
    }

    /// Mixed Gang ids
    function test_joinGangAttack_fail_IdsMustBeOfSameGang() public {
        vm.prank(bob);
        game.baronDeclareAttack(0, 1, 1001);

        vm.expectRevert(IdsMustBeOfSameGang.selector);

        vm.prank(alice);
        game.joinGangAttack(0, 1, [1, 2].toMemory());
    }

    /// Attack as baron
    function test_joinGangAttack_fail_TokenMustBeGangster() public {
        vm.prank(bob);
        game.baronDeclareAttack(0, 1, 1001);

        vm.expectRevert(TokenMustBeGangster.selector);

        vm.prank(bob);
        game.joinGangAttack(0, 1, [1001].toMemory());
    }

    /// Can't attack own district
    function test_joinGangAttack_fail_CannotAttackDistrictOwnedByGang() public {
        vm.expectRevert(CannotAttackDistrictOwnedByGang.selector);

        vm.prank(bob);
        game.baronDeclareAttack(0, 3, 1001);
    }

    // /// Locked in attack/defense
    // function test_joinGangAttack_fail_GangsterInactionable() public {
    //     vm.prank(bob);
    //     game.baronDeclareAttack(0, 1, 1001);

    //     vm.prank(alice);
    //     game.joinGangAttack(0, 1, [1].toMemory());

    //     vm.prank(alice);
    //     game.joinGangDefense(2, [2].toMemory());

    //     skip(game.getConstants().TIME_REINFORCEMENTS);

    //     vm.prank(bob);
    //     game.baronDeclareAttack(4, 5, 1004);

    //     vm.expectRevert(GangsterInactionable.selector);

    //     vm.prank(alice);
    //     game.joinGangAttack(3, 4, [1].toMemory());

    //     vm.expectRevert(GangsterInactionable.selector);

    //     vm.prank(alice);
    //     game.joinGangDefense(5, [2].toMemory());
    // }

    // /* ------------- joinGangDefense() ------------- */

    // function test_joinGangDefense() public {
    //     // vm.prank(bob);
    //     // game.baronDeclareAttack(0, 1, 1001);

    //     vm.prank(alice);
    //     game.joinGangDefense(1, [1].toMemory());

    //     GangsterView memory gangster = game.getGangster(1);

    //     assertEq(gangster.location, 1);
    //     // assertEq(gangster.state, PLAYER_STATE.DEFEND);
    //     // assertEq(gangster.roundId, game.getDistrict(1).roundId);
    //     // assertEq(uint256(gangster.stateCountdown), game.getConstants().TIME_REINFORCEMENTS);
    // }

    // // @note repeat for defense

    // /* ------------- checkUpkeep() ------------- */

    // function test_checkUpkeep() public {
    //     bool upkeepNeeded;
    //     bytes memory data;
    //     // uint256[] memory ids;
    //     uint256 ids;

    //     (upkeepNeeded, ) = game.checkUpkeep("");
    //     assertFalse(upkeepNeeded);

    //     skip(50000);

    //     (upkeepNeeded, ) = game.checkUpkeep("");
    //     assertFalse(upkeepNeeded);

    //     // first district that will need upkeep
    //     vm.prank(bob);
    //     game.baronDeclareAttack(0, 1, 1001);

    //     (upkeepNeeded, ) = game.checkUpkeep("");
    //     assertFalse(upkeepNeeded);

    //     // upkeep is needed after time passage
    //     skip(50000);

    //     (upkeepNeeded, data) = game.checkUpkeep("");
    //     assertTrue(upkeepNeeded);

    //     ids = abi.decode(data, (uint256));
    //     assertEq(ids, uint256(1) << 2);

    //     // add an additional attack that needs upkeep
    //     vm.prank(bob);
    //     game.baronDeclareAttack(4, 5, 1004);

    //     skip(50000);

    //     (upkeepNeeded, data) = game.checkUpkeep("");
    //     assertTrue(upkeepNeeded);

    //     ids = abi.decode(data, (uint256));
    //     assertEq(ids, (1 << 2) | (1 << 5));

    //     // perform upkeep
    //     game.performUpkeep(data);

    //     // performing upkeep twice does not do anything
    //     vm.record();

    //     game.performUpkeep(data);

    //     (, bytes32[] memory writes) = vm.accesses(address(game));
    //     assertEq(writes.length, 0);

    //     // checkUpkeep should be false after perform
    //     (upkeepNeeded, data) = game.checkUpkeep("");
    //     assertFalse(upkeepNeeded);

    //     ids = abi.decode(data, (uint256));
    //     assertEq(ids, 0);

    //     // waiting for 1 minute without confirming VRF call should reset request status
    //     skip(5 minutes + 1);

    //     (upkeepNeeded, data) = game.checkUpkeep("");
    //     assertTrue(upkeepNeeded);

    //     ids = abi.decode(data, (uint256));
    //     assertEq(ids, (1 << 2) | (1 << 5));
    // }

    // /* ------------- fullfillRandomWords() ------------- */

    // function test_fullfillRandomWords() public {
    //     bool upkeepNeeded;
    //     bytes memory data;

    //     vm.prank(bob);
    //     game.baronDeclareAttack(0, 1, 1001);

    //     vm.prank(bob);
    //     game.baronDeclareAttack(4, 5, 1004);

    //     skip(50000);

    //     (upkeepNeeded, data) = game.checkUpkeep("");

    //     game.performUpkeep(data);

    //     // assertions
    //     DISTRICT_STATE state2;
    //     DISTRICT_STATE state5;
    //     District memory district2;
    //     District memory district5;

    //     (district2, state2) = game.getDistrictAndState(2);
    //     (district5, state5) = game.getDistrictAndState(5);

    //     assertEq(state2, DISTRICT_STATE.POST_GANG_WAR);
    //     assertEq(state5, DISTRICT_STATE.POST_GANG_WAR);
    //     assertEq(district2.roundId, 1); // starts at 1
    //     assertEq(district5.roundId, 1);
    //     assertEq(district2.lastUpkeepTime, block.timestamp);
    //     assertEq(district5.lastUpkeepTime, block.timestamp);
    //     assertEq(district2.lastOutcomeTime, 0);
    //     assertEq(district5.lastOutcomeTime, 0);
    //     assertEq(game.getGangWarOutcome(2, 1), 0);
    //     assertEq(game.getGangWarOutcome(5, 1), 0);

    //     // upkeepNeeded should be false now
    //     (upkeepNeeded, data) = game.checkUpkeep("");
    //     // uint256[] memory ids = abi.decode(data, (uint256[]));

    //     assertFalse(upkeepNeeded);
    //     // assertEq(ids.length, 0);

    //     uint256 requestId = coordinator.requestIdCounter();
    //     vm.prank(address(coordinator));
    //     game.rawFulfillRandomWords(requestId, [1234].toMemory());

    //     (district2, state2) = game.getDistrictAndState(2);
    //     (district5, state5) = game.getDistrictAndState(5);

    //     assertEq(state2, DISTRICT_STATE.TRUCE);
    //     assertEq(state5, DISTRICT_STATE.TRUCE);
    //     assertEq(district2.roundId, 2);
    //     assertEq(district5.roundId, 2);
    //     assertEq(district2.lastOutcomeTime, block.timestamp);
    //     assertEq(district5.lastOutcomeTime, block.timestamp);
    //     assertTrue(game.getGangWarOutcome(2, 1) > 0);
    //     assertTrue(game.getGangWarOutcome(5, 1) > 0);

    //     // check district state

    //     // upkeep should remain false, even after 1 additional minute
    //     skip(1 minutes + 1);
    //     (upkeepNeeded, data) = game.checkUpkeep("");
    //     uint256[] memory ids = abi.decode(data, (uint256[]));

    //     assertFalse(upkeepNeeded);
    //     assertEq(ids.length, 0);
    // }

    // // function test_performUpkeep_twice() public {
    // //     vm.prank(bob);
    // //     game.baronDeclareAttack(0, 1, 1001);

    // //     vm.prank(bob);
    // //     game.baronDeclareAttack(4, 5, 1004);

    // //     skip(50000);

    // //     (, bytes memory data) = game.checkUpkeep("");

    // //     game.performUpkeep(data);

    // //     // performing upkeep twice shouldn't change any assertions
    // //     game.performUpkeep(data);

    // //     assertEq(game.getDistrict(2).roundId, 2);
    // //     assertEq(game.getDistrict(5).roundId, 2);
    // //     assertEq(game.getDistrict(2).lastUpkeepTime, block.timestamp);
    // //     assertEq(game.getDistrict(5).lastUpkeepTime, block.timestamp);

    // //     assertTrue(game.getGangWarOutcome(2, 1) > 0);
    // //     assertTrue(game.getGangWarOutcome(5, 1) > 0);
    // // }

    // // function test_performUpkeep_fail_() public {
    // //     game.performUpkeep(abi.encode([1].toMemory()));
    // // }

    // // @note validate absolute attack forces and gang yields
}
