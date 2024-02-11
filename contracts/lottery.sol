//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

contract lottery is VRFV2WrapperConsumerBase, ConfirmedOwner {
    event NewParticipant(address indexed newParticipant, bool isNewParticipant);
    event Winner(address indexed winnerAddress, bool isWinner);
    event Paused(address account);
    event Unpaused(address account);
    event RandomNumberRequested(uint256 requestId);
    event RandomNumberFulfilled(uint256 randomNumber);


    struct RequestStatus {
        uint256 paid; 
        bool fulfilled;
        uint256 randomNumber;
    }

    uint32 callbackGasLimit = 2000000;
    uint32 numNumber = 1;
    uint16 requestConfirmations = 3;
    mapping(uint256 => RequestStatus) public s_requests;

    address payable public ownerPayable;
    uint256 public lotteryId;
    mapping(address => mapping(uint256 => bool)) public hasParticipatedThisRound;
    mapping(uint256 => address) public indexToParticipant;
    uint256 public participantCount;
    address public lastWinner;
    bool public paused;
    bool private locked;

    address linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address wrapperAddress = 0x99aFAf084eBA697E584501b8Ed2c0B37Dd136693;
    uint256[] public requestIds;
    uint256 public lastRequestId;

    constructor()
        ConfirmedOwner(msg.sender)
        VRFV2WrapperConsumerBase(linkAddress, wrapperAddress)
    {
        ownerPayable = payable(msg.sender);
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
    function _requestRandomNumber() internal returns (uint256 requestId) {
        requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numNumber
        );

        s_requests[requestId] = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomNumber: 0,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;

        emit RandomNumberRequested(requestId);
    }


    function selectWinner() public onlyOwner hasParticipants hasEnoughBalance noReentrancy {
        _requestRandomNumber();
    }

    // callback function call by chainlink to give here the random number
    function fulfillRandomWords(uint256 _requestId, uint256[] memory randomWords) internal override {
        require(s_requests[_requestId].paid > 0, "request not found");

        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomNumber = randomWords[0];
        
        emit RandomNumberFulfilled(randomWords[0]);
        _processWinner(randomWords[0]);
    }

    function _processWinner(uint256 randomness) internal {
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
