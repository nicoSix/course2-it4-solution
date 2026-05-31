// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VoteToken} from "votetoken/src/VoteToken.sol";

contract VoteContract {
    string public question;
    VoteToken public voteToken;
    string[] public answers;
    uint256 public deadline;
    bool public resolved;
    uint256 public winningAnswerIndex;
    mapping(uint256 => uint256) public votesFor;
    mapping(address => uint256) public depositedBy;
    address[] public voters;

    error EmptyQuestion();
    error NotEnoughAnswers();
    error InvalidDeadline();
    error InvalidAnswer(uint256 answerIndex);
    error ZeroAmount();
    error TransferFailed();
    error VotingClosed();
    error VotingStillOpen();
    error AlreadyResolved();

    event Voted(address indexed voter, uint256 indexed answerIndex, uint256 amount);
    event Resolved(uint256 indexed winningAnswerIndex, uint256 votes);
    event Refunded(address indexed voter, uint256 amount);

    constructor(string memory _question, VoteToken _voteToken, string[] memory _answers, uint256 _deadline) {
        if (bytes(_question).length == 0) {
            revert EmptyQuestion();
        }
        if (_answers.length < 2) {
            revert NotEnoughAnswers();
        }
        if (_deadline <= block.timestamp) {
            revert InvalidDeadline();
        }

        question = _question;
        voteToken = _voteToken;
        answers = _answers;
        deadline = _deadline;
    }

    function vote(uint256 answerIndex, uint256 amount) public {
        if (block.timestamp >= deadline) {
            revert VotingClosed();
        }
        if (answerIndex >= answers.length) {
            revert InvalidAnswer(answerIndex);
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        bool ok = voteToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) {
            revert TransferFailed();
        }

        if (depositedBy[msg.sender] == 0) {
            voters.push(msg.sender);
        }

        votesFor[answerIndex] += amount;
        depositedBy[msg.sender] += amount;

        emit Voted(msg.sender, answerIndex, amount);
    }

    function resolve() public returns (uint256) {
        if (block.timestamp < deadline) {
            revert VotingStillOpen();
        }
        if (resolved) {
            revert AlreadyResolved();
        }

        uint256 winner = winningAnswer();

        resolved = true;
        winningAnswerIndex = winner;
        emit Resolved(winner, votesFor[winner]);

        uint256 voterCount = voters.length;
        for (uint256 i = 0; i < voterCount; i++) {
            address voter = voters[i];
            uint256 amount = depositedBy[voter];
            if (amount == 0) {
                continue;
            }

            depositedBy[voter] = 0;

            bool ok = voteToken.transfer(voter, amount);
            if (!ok) {
                revert TransferFailed();
            }

            emit Refunded(voter, amount);
        }

        return winner;
    }

    function votersCount() public view returns (uint256) {
        return voters.length;
    }

    function votingOpen() public view returns (bool) {
        return block.timestamp < deadline;
    }

    function answersCount() public view returns (uint256) {
        return answers.length;
    }

    function getAnswers() public view returns (string[] memory) {
        return answers;
    }

    function winningAnswer() public view returns (uint256 winningIndex) {
        uint256 highest = votesFor[0];
        for (uint256 i = 1; i < answers.length; i++) {
            if (votesFor[i] > highest) {
                highest = votesFor[i];
                winningIndex = i;
            }
        }
    }
}
