// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";

contract CounterReadScript is Script {
    function run() public view {
        address counterAddress = vm.envAddress("COUNTER_ADDRESS");
        Counter counter = Counter(counterAddress);

        console.log("Counter number:", counter.number());
    }
}
