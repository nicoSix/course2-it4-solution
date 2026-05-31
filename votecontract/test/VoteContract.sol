// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {VoteContract} from "../src/VoteContract.sol";
import {VoteToken} from "votetoken/src/VoteToken.sol";

contract VoteContractTest is Test {
    VoteToken token;
    VoteContract poll;

    address deployer = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant INITIAL_SUPPLY = 1_000 ether;
    uint8 constant EXCHANGE_RATE = 100;

    string constant QUESTION = "What is your favourite colour?";

    uint256 constant VOTING_PERIOD = 7 days;
    uint256 deadline;

    function setUp() public {
        token = new VoteToken(INITIAL_SUPPLY, EXCHANGE_RATE);
        deadline = block.timestamp + VOTING_PERIOD;

        string[] memory answers = new string[](3);
        answers[0] = "Red";
        answers[1] = "Green";
        answers[2] = "Blue";

        poll = new VoteContract(QUESTION, token, answers, deadline);
    }

    function _vote(address voter, uint256 answerIndex, uint256 amount) internal {
        deal(address(token), voter, amount);
        vm.prank(voter);
        token.approve(address(poll), amount);
        vm.prank(voter);
        poll.vote(answerIndex, amount);
    }

    function _twoAnswers() internal pure returns (string[] memory answers) {
        answers = new string[](2);
        answers[0] = "Yes";
        answers[1] = "No";
    }

    function test_Constructor_StoresQuestion() public view {
        assertEq(poll.question(), QUESTION);
    }

    function test_Constructor_StoresVoteToken() public view {
        assertEq(address(poll.voteToken()), address(token));
    }

    function test_Constructor_StoresAnswers() public view {
        assertEq(poll.answersCount(), 3);
        assertEq(poll.answers(0), "Red");
        assertEq(poll.answers(1), "Green");
        assertEq(poll.answers(2), "Blue");

        string[] memory all = poll.getAnswers();
        assertEq(all.length, 3);
        assertEq(all[2], "Blue");
    }

    function test_Constructor_StoresDeadline() public view {
        assertEq(poll.deadline(), deadline);
        assertTrue(poll.votingOpen());
        assertFalse(poll.resolved());
    }

    function test_Constructor_RevertsOnEmptyQuestion() public {
        string[] memory answers = _twoAnswers();

        vm.expectRevert(VoteContract.EmptyQuestion.selector);
        new VoteContract("", token, answers, deadline);
    }

    function test_Constructor_RevertsWithFewerThanTwoAnswers() public {
        string[] memory answers = new string[](1);
        answers[0] = "Only one";

        vm.expectRevert(VoteContract.NotEnoughAnswers.selector);
        new VoteContract(QUESTION, token, answers, deadline);
    }

    function test_Constructor_RevertsOnPastDeadline() public {
        string[] memory answers = _twoAnswers();

        vm.expectRevert(VoteContract.InvalidDeadline.selector);
        new VoteContract(QUESTION, token, answers, block.timestamp);
    }

    function test_Vote_TransfersTokensToContract() public {
        uint256 amount = 50 ether;
        deal(address(token), alice, amount);
        vm.prank(alice);
        token.approve(address(poll), amount);

        vm.prank(alice);
        poll.vote(0, amount);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(poll)), amount);
    }

    function test_Vote_TalliesWeightByDepositedAmount() public {
        uint256 amount = 30 ether;
        deal(address(token), alice, amount);
        vm.prank(alice);
        token.approve(address(poll), amount);

        vm.prank(alice);
        poll.vote(2, amount);

        assertEq(poll.votesFor(2), amount);
        assertEq(poll.depositedBy(alice), amount);
    }

    function test_Vote_AccumulatesAcrossVoters() public {
        deal(address(token), alice, 10 ether);
        deal(address(token), bob, 25 ether);
        vm.prank(alice);
        token.approve(address(poll), 10 ether);
        vm.prank(bob);
        token.approve(address(poll), 25 ether);

        vm.prank(alice);
        poll.vote(1, 10 ether);
        vm.prank(bob);
        poll.vote(1, 25 ether);

        assertEq(poll.votesFor(1), 35 ether);
    }

    function test_Vote_EmitsVotedEvent() public {
        uint256 amount = 5 ether;
        deal(address(token), alice, amount);
        vm.prank(alice);
        token.approve(address(poll), amount);

        vm.expectEmit(true, true, false, true, address(poll));
        emit VoteContract.Voted(alice, 0, amount);
        vm.prank(alice);
        poll.vote(0, amount);
    }

    function test_Vote_RevertsOnInvalidAnswer() public {
        deal(address(token), alice, 1 ether);
        vm.prank(alice);
        token.approve(address(poll), 1 ether);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(VoteContract.InvalidAnswer.selector, 3));
        poll.vote(3, 1 ether);
    }

    function test_Vote_RevertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(VoteContract.ZeroAmount.selector);
        poll.vote(0, 0);
    }

    function test_Vote_RevertsWithoutApproval() public {
        deal(address(token), alice, 1 ether);

        vm.prank(alice);
        vm.expectRevert();
        poll.vote(0, 1 ether);
    }

    function test_WinningAnswer_ReturnsMostVoted() public {
        deal(address(token), alice, 10 ether);
        deal(address(token), bob, 40 ether);
        vm.prank(alice);
        token.approve(address(poll), 10 ether);
        vm.prank(bob);
        token.approve(address(poll), 40 ether);

        vm.prank(alice);
        poll.vote(0, 10 ether);
        vm.prank(bob);
        poll.vote(2, 40 ether);

        assertEq(poll.winningAnswer(), 2);
    }

    function test_WinningAnswer_TieGoesToLowestIndex() public {
        deal(address(token), alice, 10 ether);
        deal(address(token), bob, 10 ether);
        vm.prank(alice);
        token.approve(address(poll), 10 ether);
        vm.prank(bob);
        token.approve(address(poll), 10 ether);

        vm.prank(alice);
        poll.vote(1, 10 ether);
        vm.prank(bob);
        poll.vote(2, 10 ether);

        assertEq(poll.winningAnswer(), 1);
    }

    function test_Vote_RevertsAfterDeadline() public {
        deal(address(token), alice, 1 ether);
        vm.prank(alice);
        token.approve(address(poll), 1 ether);
        vm.warp(deadline);

        vm.prank(alice);
        vm.expectRevert(VoteContract.VotingClosed.selector);
        poll.vote(0, 1 ether);
    }

    function test_VotingOpen_FlipsAtDeadline() public {
        assertTrue(poll.votingOpen());

        vm.warp(deadline);

        assertFalse(poll.votingOpen());
    }

    function test_Resolve_SetsWinningAnswer() public {
        _vote(alice, 0, 10 ether);
        _vote(bob, 2, 40 ether);
        vm.warp(deadline);

        uint256 winner = poll.resolve();

        assertEq(winner, 2);
        assertTrue(poll.resolved());
        assertEq(poll.winningAnswerIndex(), 2);
    }

    function test_Resolve_EmitsResolvedEvent() public {
        _vote(alice, 1, 15 ether);
        vm.warp(deadline);

        vm.expectEmit(true, false, false, true, address(poll));
        emit VoteContract.Resolved(1, 15 ether);
        poll.resolve();
    }

    function test_Resolve_RevertsBeforeDeadline() public {
        vm.expectRevert(VoteContract.VotingStillOpen.selector);
        poll.resolve();
    }

    function test_Resolve_RevertsWhenAlreadyResolved() public {
        vm.warp(deadline);
        poll.resolve();

        vm.expectRevert(VoteContract.AlreadyResolved.selector);
        poll.resolve();
    }

    function test_Resolve_RefundsEachVoter() public {
        _vote(alice, 0, 10 ether);
        _vote(bob, 2, 40 ether);
        assertEq(token.balanceOf(address(poll)), 50 ether);
        vm.warp(deadline);

        poll.resolve();

        assertEq(token.balanceOf(alice), 10 ether);
        assertEq(token.balanceOf(bob), 40 ether);
        assertEq(token.balanceOf(address(poll)), 0);
        assertEq(poll.depositedBy(alice), 0);
        assertEq(poll.depositedBy(bob), 0);
    }

    function test_Resolve_RefundsAggregatedDepositOncePerVoter() public {
        _vote(alice, 0, 10 ether);
        _vote(alice, 1, 15 ether);
        assertEq(poll.votersCount(), 1);
        vm.warp(deadline);

        poll.resolve();

        assertEq(token.balanceOf(alice), 25 ether);
        assertEq(token.balanceOf(address(poll)), 0);
    }

    function test_Resolve_EmitsRefundedEvent() public {
        _vote(alice, 1, 15 ether);
        vm.warp(deadline);

        vm.expectEmit(true, false, false, true, address(poll));
        emit VoteContract.Refunded(alice, 15 ether);
        poll.resolve();
    }
}
