// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VoteToken is ERC20 {
    uint8 _exchangeRate;
    uint256 _initialSupply;

    error NoWeiProvided();
    error NotEnoughToken(uint256 expectedAmount, uint256 availableAmount);

    event Gambled(address indexed player, uint256 stake, bool won);
    event Bought(address indexed buyer, uint256 amount);

    constructor(uint256 initialSupply, uint8 exchangeRate) ERC20("My Token", "MT") {
        _exchangeRate = exchangeRate;
        _initialSupply = initialSupply;
        _mint(msg.sender, _initialSupply);
    }

    function buy() public payable hasWei {
        uint256 boughtAmount = msg.value * _exchangeRate;
        _mint(msg.sender, boughtAmount);
        emit Bought(msg.sender, boughtAmount);
    }

    function gamble(uint256 amount) public hasEnoughToken(amount) {
        bool won = uint256(keccak256(abi.encodePacked(block.prevrandao, msg.sender, amount))) % 2 == 0;

        if (won) {
            _mint(msg.sender, amount);
        } else {
            _burn(msg.sender, amount);
        }

        emit Gambled(msg.sender, amount, won);
    }

    modifier hasWei() {
        if (msg.value <= 0) {
            revert NoWeiProvided();
        }

        _;
    }

    modifier hasEnoughToken(uint256 amount) {
        if (this.balanceOf(msg.sender) < amount) {
            revert NotEnoughToken(amount, this.balanceOf(msg.sender));
        }
        _;
    }
}
