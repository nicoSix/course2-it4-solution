// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {VoteToken} from "../src/VoteToken.sol";

contract VoteTokenTest is Test {
    VoteToken token;

    address deployer = address(this);
    address alice = makeAddr("alice");

    uint256 constant INITIAL_SUPPLY = 1_000 ether;
    uint8 constant EXCHANGE_RATE = 100;

    function setUp() public {
        token = new VoteToken(INITIAL_SUPPLY, EXCHANGE_RATE);
    }

    function test_Constructor_SetsNameAndSymbol() public view {
        assertEq(token.name(), "My Token");
        assertEq(token.symbol(), "MT");
    }

    function test_Constructor_DefaultDecimalsIs18() public view {
        assertEq(token.decimals(), 18);
    }

    function test_Constructor_MintsInitialSupplyToDeployer() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY);
    }

    function test_Buy_MintsTokensProportionalToValue() public {
        uint256 sent = 1 ether;
        vm.deal(alice, sent);

        vm.prank(alice);
        token.buy{value: sent}();

        assertEq(token.balanceOf(alice), sent * EXCHANGE_RATE);
    }

    function test_Buy_IncreasesTotalSupply() public {
        uint256 sent = 0.5 ether;
        vm.deal(alice, sent);
        uint256 supplyBefore = token.totalSupply();

        vm.prank(alice);
        token.buy{value: sent}();

        assertEq(token.totalSupply(), supplyBefore + sent * EXCHANGE_RATE);
    }

    function test_Buy_ForwardsEtherToContract() public {
        uint256 sent = 2 ether;
        vm.deal(alice, sent);

        vm.prank(alice);
        token.buy{value: sent}();

        assertEq(address(token).balance, sent);
    }

    function test_Buy_RevertsWhenNoEtherSent() public {
        vm.prank(alice);
        vm.expectRevert(VoteToken.NoWeiProvided.selector);
        token.buy();
    }

    function test_Gamble_Won() public {
        uint256 stake = 100 ether;
        deal(address(token), alice, stake);
        vm.prevrandao(_seedFor(alice, stake, true));

        vm.prank(alice);
        token.gamble(stake);

        assertEq(token.balanceOf(alice), stake * 2);
    }

    function test_Gamble_Lost() public {
        uint256 stake = 100 ether;
        deal(address(token), alice, stake);
        vm.prevrandao(_seedFor(alice, stake, false));

        vm.prank(alice);
        token.gamble(stake);

        assertEq(token.balanceOf(alice), 0);
    }

    function test_Gamble_RevertWhenNotEnoughTokens() public {
        uint256 stake = 100 ether;

        vm.prank(alice);

        vm.expectPartialRevert(VoteToken.NotEnoughToken.selector);
        token.gamble(stake);
    }

    function testFuzz_Buy_MintsCorrectAmount(uint96 sent) public {
        vm.assume(sent > 0);
        vm.deal(alice, sent);

        vm.prank(alice);
        token.buy{value: sent}();

        assertEq(token.balanceOf(alice), uint256(sent) * EXCHANGE_RATE);
    }

    function _seedFor(address player, uint256 amount, bool wantWin) internal pure returns (bytes32) {
        for (uint256 i = 0; i < 256; i++) {
            bool wouldWin = uint256(keccak256(abi.encodePacked(i, player, amount))) % 2 == 0;
            if (wouldWin == wantWin) return bytes32(i);
        }

        revert("no seed found");
    }
}
