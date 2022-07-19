// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "solmate/test/utils/mocks/MockERC721.sol";

// import "../src/Test.sol";

/* 
forge script script/GangWar.s.sol:Deploy --rpc-url $RINKEBY_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
forge script script/GangWar.s.sol:Deploy --rpc-url $PROVIDER_MUMBAI  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv
forge script script/GangWar.s.sol:Deploy --rpc-url https://rpc.ankr.com/polygon  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 30gwei -vvvv
*/

contract Deploy is Script {
    // Test test;

    function run() external {
        vm.startBroadcast();

        // MockERC721 mock = new MockERC721("GMC", "GMC");

        vm.stopBroadcast();
    }

    function validate() internal {}
}
