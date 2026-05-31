// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";

contract CounterIncrementScript is Script {
    function run() public {
        address counterAddress = vm.envAddress("COUNTER_ADDRESS");
        Counter counter = Counter(counterAddress);

        vm.startBroadcast();
        counter.increment();
        vm.stopBroadcast();

        console.log("Counter number:", counter.number());
    }
}
