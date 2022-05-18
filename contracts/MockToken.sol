//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/// @title Whale Game - Tamagotchi
/// @author Ace

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract testAqua is ERC20{

    constructor() ERC20("test Aqua","Aqua"){}

    function mint(uint amount) external {
        _mint(msg.sender,amount* 1 ether);
    }

}