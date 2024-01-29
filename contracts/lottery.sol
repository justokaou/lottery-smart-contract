//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

contract lottery is VRFConsumerBaseV2, ConfirmedOwner {
    event NewParticipant(address indexed newParticipant, bool isNewParticipant);
    event Winner(address indexed winnerAddress, bool isWinner);
    event Paused(address account);
    event Unpaused(address account);
    event RandomNumberRequested(uint256 requestId);
    event RandomNumberFulfilled(uint256 randomNumber);


    struct RequestStatus {
        bool fulfilled;
        uint256 randomNumber;
    }

    VRFCoordinatorV2Interface COORDINATOR;
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;
    uint32 callbackGasLimit = 2500000;
    uint32 numNumber = 1;
    uint16 requestConfirmations = 3;
    uint64 s_subscriptionId;
    mapping(uint256 => RequestStatus) public s_requests;

    address payable public ownerPayable;
    uint256 public lotteryId = 0;
    mapping(address => mapping(uint256 => bool)) public hasParticipatedThisRound;
    mapping(uint256 => address) public indexToParticipant;
    uint256 public participantCount;
    address public lastWinner;
    bool public paused = false;
    bool private locked;

    constructor(uint64 subscriptionId) 
        VRFConsumerBaseV2(0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(
            0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed // VRF Coordinator for Mumbai
        );
        ownerPayable = payable(msg.sender);
        keyHash = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
        fee = 0.0005 * 10 ** 18; // Fee for Mumbai
        s_subscriptionId = subscriptionId; // define subscription id
        COORDINATOR = VRFCoordinatorV2Interface(0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed);
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

    // request random number to chainlink VRF
    function requestRandomNumber() internal {
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash, 
            s_subscriptionId, 
            requestConfirmations, // request confirmations
            callbackGasLimit, // callback gas limit
            numNumber // number of random numbers
        );
        emit RandomNumberRequested(uint256(requestId));
    }


    function selectWinner() public onlyOwner hasParticipants hasEnoughBalance noReentrancy {
        requestRandomNumber();
    }

    // callback function call by chainlink to give here the random number
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        randomResult = randomWords[0];
        emit RandomNumberFulfilled(randomResult);
        processWinner(randomResult);
    }

    function processWinner(uint256 randomness) internal {
        // Use randomness to determine the winner
        uint256 randomIndex = randomness % participantCount;
        address winnerAddress = indexToParticipant[randomIndex];

        // transfer rewards
        uint256 ownerShare = address(this).balance * 5 / 100;
        (bool sentOwner, ) = ownerPayable.call{value: ownerShare}("");
        require(sentOwner, "Failed to send Ether to owner");

        uint256 winnerReward = address(this).balance;
        (bool sentWinner, ) = payable(winnerAddress).call{value: winnerReward}("");
        require(sentWinner, "Failed to send Ether to winner");

        lastWinner = winnerAddress;
        emit Winner(winnerAddress, true);

        // reset for next lottery
        lotteryId++;
        participantCount = 0;
    }

}
