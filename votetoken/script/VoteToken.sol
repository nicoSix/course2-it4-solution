// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {VoteToken} from "../src/VoteToken.sol";

contract VoteTokenScript is Script {
    function run() public {
        address voteTokenAddress = vm.envAddress("VOTE_TOKEN_ADDRESS");
        VoteToken voteToken = VoteToken(voteTokenAddress);

        vm.startBroadcast();
        voteToken.buy{value: 0.001 ether}();
        vm.stopBroadcast();

        console.log("Token balance:", voteToken.balanceOf(msg.sender));
    }
}
