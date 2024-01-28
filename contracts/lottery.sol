//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract lottery {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event NewParticipant(address indexed newParticipant, bool isNewParticipant);
    event Winner(address indexed winnerAddress, bool isWinner);
    event Paused(address account);
    event Unpaused(address account);

    address public owner;
    uint256 public lotteryId = 0;
    mapping(address => mapping(uint256 => bool)) public hasParticipatedThisRound;
    mapping(uint256 => address) public indexToParticipant;
    uint256 public participantCount;
    address public lastWinner;
    bool public paused = false;
    bool private locked;

    constructor() {
        owner = msg.sender; // Le créateur du contrat est le propriétaire
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is currently paused");
        _;
    }

    modifier noReentrancy() {
        require(!locked, "No reentrancy allowed");
        locked = true;
        _;
        locked = false;
    }

    modifier hasEnoughBalance() {
        require(address(this).balance > 0, "Not enough balance to select a winner");
        _;
    }

    modifier hasParticipants() {
        require(participantCount > 0, "No participants");
        _;
    }


    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function pause() public onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function participate() public payable whenNotPaused {
        require(msg.value == 0.1 ether, "Must send 0.1 ETH");
        require(!hasParticipatedThisRound[msg.sender][lotteryId], "Already participated this round");

        indexToParticipant[participantCount] = msg.sender;
        hasParticipatedThisRound[msg.sender][lotteryId] = true;

        emit NewParticipant(indexToParticipant[participantCount], hasParticipatedThisRound[msg.sender][lotteryId]);
        participantCount++;
    }

    function selectWinner() public onlyOwner hasParticipants hasEnoughBalance noReentrancy {
        uint256 randomIndex = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % participantCount;

        address winnerAddress = indexToParticipant[randomIndex];

        uint256 ownerShare = address(this).balance * 5 / 100;

        (bool sentOwner, ) = payable(owner).call{value: ownerShare}("");
        require(sentOwner, "Failed to send Ether to owner");

        // Calculer le reste pour le gagnant
        uint256 winnerReward = address(this).balance; // La balance restante après le transfert à l'owner
        (bool sentWinner, ) = payable(winnerAddress).call{value: winnerReward}("");
        require(sentWinner, "Failed to send Ether to winner");

        lastWinner = winnerAddress;
        emit Winner(winnerAddress, true);

        lotteryId++;
        participantCount = 0;
    }
}
