// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

/// @title Lottery Contract with Chainlink VRF for Random Number Generation
/// @notice This contract allows users to participate in a lottery and selects a random winner using Chainlink VRF.
/// @dev Utilizes Chainlink VRF v2 and implements anti-reentrancy measures.
contract lottery is VRFV2WrapperConsumerBase, ConfirmedOwner {
    
    /// @notice Emitted when a new participant enters the lottery.
    /// @param newParticipant The address of the new participant.
    /// @param isNewParticipant A boolean indicating if they successfully joined.
    event NewParticipant(address indexed newParticipant, bool isNewParticipant);

    /// @notice Emitted when a winner is selected.
    /// @param winnerAddress The address of the selected winner.
    /// @param isWinner A boolean indicating if the address is the winner.
    event Winner(address indexed winnerAddress, bool isWinner);

    /// @notice Emitted when the contract is paused.
    /// @param account The address that paused the contract.
    event Paused(address account);

    /// @notice Emitted when the contract is unpaused.
    /// @param account The address that unpaused the contract.
    event Unpaused(address account);

    /// @notice Emitted when a random number is requested from Chainlink VRF.
    /// @param requestId The ID of the randomness request.
    event RandomNumberRequested(uint256 requestId);

    /// @notice Emitted when a random number request is fulfilled by Chainlink VRF.
    /// @param randomNumber The random number returned by Chainlink VRF.
    event RandomNumberFulfilled(uint256 randomNumber);

    /// @notice Structure to store the status of a randomness request.
    /// @dev Tracks whether the request has been fulfilled and stores the random number.
    /// @param paid The amount paid for the VRF request.
    /// @param fulfilled Boolean indicating whether the randomness request has been fulfilled.
    /// @param randomNumber The random number provided by Chainlink.
    struct RequestStatus {
        uint256 paid;
        bool fulfilled;
        uint256 randomNumber;
    }

    uint32 callbackGasLimit = 2000000; ///< Gas limit for the callback function.
    uint32 numNumber = 1; ///< Number of random numbers requested from Chainlink.
    uint16 requestConfirmations = 3; ///< Number of block confirmations required before fulfilling the randomness request.

    mapping(uint256 => RequestStatus) public s_requests; ///< Stores request statuses based on request ID.

    address payable public ownerPayable; ///< The owner address, payable for receiving owner fees.
    uint256 public lotteryId; ///< ID of the current lottery round.
    mapping(address => mapping(uint256 => bool)) public hasParticipatedThisRound; ///< Tracks whether a participant has joined a given lottery round.
    mapping(uint256 => address) public indexToParticipant; ///< Maps participant index to address.
    uint256 public participantCount; ///< Number of participants in the current round.
    address public lastWinner; ///< Stores the address of the last lottery winner.
    bool public paused; ///< Indicates whether the contract is paused.
    bool private locked; ///< Used for reentrancy protection.

    address linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB; ///< Address of the LINK token on the current network.
    address wrapperAddress = 0x99aFAf084eBA697E584501b8Ed2c0B37Dd136693; ///< Address of the Chainlink VRF wrapper contract.

    uint256[] public requestIds; ///< List of all randomness request IDs.
    uint256 public lastRequestId; ///< The ID of the last randomness request.

    /// @notice Constructor to initialize the contract.
    /// @dev Initializes the Chainlink VRF and the owner.
    constructor()
        ConfirmedOwner(msg.sender)
        VRFV2WrapperConsumerBase(linkAddress, wrapperAddress)
    {
        ownerPayable = payable(msg.sender);
    }

    /// @notice Ensures the function can only be called when the contract is not paused.
    modifier whenNotPaused() {
        require(!paused, "Contract is currently paused");
        _;
    }

    /// @notice Prevents reentrancy attacks by locking the contract during critical execution.
    modifier noReentrancy() {
        require(!locked, "No reentrancy allowed");
        locked = true;
        _;
        locked = false;
    }

    /// @notice Ensures that the contract has sufficient balance to select a winner.
    modifier hasEnoughBalance() {
        require(address(this).balance > 0, "Not enough balance to select a winner");
        _;
    }

    /// @notice Ensures there are participants in the lottery before selecting a winner.
    modifier hasParticipants() {
        require(participantCount > 0, "No participants");
        _;
    }

    /// @notice Pauses the contract, preventing new participants.
    /// @dev Only the owner can call this function.
    function pause() public onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpauses the contract, allowing new participants.
    /// @dev Only the owner can call this function.
    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Allows a user to participate in the lottery by sending exactly 0.1 ETH.
    /// @dev Users can only participate if the contract is not paused and if they haven't participated in the current round.
    function participate() public payable whenNotPaused {
        require(msg.value == 0.1 ether, "Must send 0.1 ETH");
        require(!hasParticipatedThisRound[msg.sender][lotteryId], "Already participated this round");

        indexToParticipant[participantCount] = msg.sender;
        hasParticipatedThisRound[msg.sender][lotteryId] = true;

        emit NewParticipant(indexToParticipant[participantCount], hasParticipatedThisRound[msg.sender][lotteryId]);
        participantCount++;
    }

    /// @notice Requests a random number from Chainlink VRF.
    /// @dev This function is called internally when selecting a winner.
    /// @return requestId The ID of the randomness request.
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

    /// @notice Selects a winner from the participants.
    /// @dev This function can only be called by the owner and requires that there are participants and sufficient balance in the contract.
    function selectWinner() public onlyOwner hasParticipants hasEnoughBalance noReentrancy {
        _requestRandomNumber();
    }

    /// @notice Callback function used by Chainlink VRF to provide a random number.
    /// @dev This function is automatically called by the Chainlink VRF coordinator when the randomness request is fulfilled.
    /// @param _requestId The ID of the randomness request.
    /// @param randomWords The random numbers provided by Chainlink VRF.
    function fulfillRandomWords(uint256 _requestId, uint256[] memory randomWords) internal override {
        require(s_requests[_requestId].paid > 0, "Request not found");

        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomNumber = randomWords[0];
        
        emit RandomNumberFulfilled(randomWords[0]);
        _processWinner(randomWords[0]);
    }

    /// @notice Processes the winner selection and distributes the rewards.
    /// @dev Uses the random number to determine the winner and transfers the prize pool.
    /// @param randomness The random number used to select the winner.
    function _processWinner(uint256 randomness) internal {
        uint256 randomIndex = randomness % participantCount;
        address winnerAddress = indexToParticipant[randomIndex];

        // Transfer 5% of the balance to the contract owner.
        uint256 ownerShare = address(this).balance * 5 / 100;
        (bool sentOwner, ) = ownerPayable.call{value: ownerShare}("");
        require(sentOwner, "Failed to send Ether to owner");

        // Transfer the remaining balance to the winner.
        uint256 winnerReward = address(this).balance;
        (bool sentWinner, ) = payable(winnerAddress).call{value: winnerReward}("");
        require(sentWinner, "Failed to send Ether to winner");

        lastWinner = winnerAddress;
        emit Winner(winnerAddress, true);

        // Reset the lottery for the next round.
        lotteryId++;
        participantCount = 0;
    }
}
