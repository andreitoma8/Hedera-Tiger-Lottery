//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./hip-206/HederaTokenService.sol";

contract TigerLottery is HederaTokenService {
    // Struct for the state of the Lottery
    enum LOTTERY_STATE {
        CLOSED,
        OPEN,
        CALCULATING_WINNER
    }

    // The price in Mingo for one Ticket
    int64 public ticketPrice = 10000;

    // The state of the Lottery
    LOTTERY_STATE public lotteryState = LOTTERY_STATE.CLOSED;

    // The address for the NFT Collection of each lottery run
    mapping(uint256 => address) public lotteriesNFTAddress;

    // The amount of tickets bought for each Lottery run
    mapping(uint256 => uint256) public lotteryTicketEntries;

    // The owner of the tickets for each Lottery run
    mapping(uint256 => mapping(int64 => address)) ownerOfTickets;

    // The total number of lotteries run
    uint256 public lotteriesCount;

    // The amount of tickets available for a lottery run
    uint64 public lotteryEntriesCap = 1000000;

    // The address of the Mingo token
    address public mingoToken;

    // The owner of the Smart Contract
    address public owner;

    constructor(address _tokenAddress) {
        mingoToken = _tokenAddress;
        owner = msg.sender;
    }

    // Only owner can call the function with this modifier
    modifier onlyOwner() {
        require(owner == msg.sender, "You are not the owner of this SC!");
        _;
    }

    // Buy a ticket for the lottery. If the amount of tickets bought is greater than or
    // equal with the tickets cap for a lottery, initiate the Lottery winner selection.
    function buyEntryTicket(int64 _amount, bytes[] memory metadata) external {
        require(lotteryState == LOTTERY_STATE.OPEN, "Lottery not open yet");
        // ToDo: Add mingo payment here.
        tokenTransfer(ticketPrice * _amount, msg.sender, address(this));
        //ToDo: Add mint NFT here.
        (uint64 newTotalSupply, int64[] memory serialNumbers) = mintTo(
            _amount,
            msg.sender,
            lotteriesNFTAddress[lotteriesCount],
            metadata
        );
        for (uint64 i; i < serialNumbers.length; ++i) {
            ownerOfTickets[lotteriesCount][serialNumbers[i]] = msg.sender;
        }
        if (newTotalSupply >= lotteryEntriesCap) {
            endLottery(newTotalSupply);
        }
    }

    // Start a new Lottery run. Only callable by owner
    function startLottery() external onlyOwner {
        lotteryState = LOTTERY_STATE.OPEN;
    }

    // Add a new NFT collection for tickets to set up a new lottery
    // and start it. Only callable by owner
    function createLottery(address _tokenAddress) external onlyOwner {
        require(
            lotteryState == LOTTERY_STATE.CLOSED,
            "A lottery is already in place"
        );
        int256 response = HederaTokenService.associateToken(
            address(this),
            _tokenAddress
        );

        if (response != HederaResponseCodes.SUCCESS) {
            revert("Associate Failed");
        }
        lotteriesCount++;
        lotteriesNFTAddress[lotteriesCount] = _tokenAddress;
        lotteryState = LOTTERY_STATE.OPEN;
    }

    // Function that selects the winner, sends rewards and ends lottery
    function endLottery(uint64 _newTotalSupply) internal {
        lotteryState = LOTTERY_STATE.CLOSED;
        uint64 winnerSerialNumber = uint64(
            uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender)))
        ) % _newTotalSupply;
        address winnerAddress = ownerOfTickets[lotteriesCount][
            int64(winnerSerialNumber)
        ];
        // ToDo: Add winner payment logic here
        tokenTransfer(
            (((int64(uint64(lotteryTicketEntries[lotteriesCount])) *
                ticketPrice) * 10) / 6),
            address(this),
            winnerAddress
        );
    }

    // Transfer ownership of the SC
    function transferOwnership(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }

    // Helper functions

    function tokenAssociate() external onlyOwner {
        int256 response = HederaTokenService.associateToken(
            address(this),
            mingoToken
        );

        if (response != HederaResponseCodes.SUCCESS) {
            revert("Associate Failed");
        }
    }

    function tokenTransfer(
        int64 _amount,
        address _from,
        address _to
    ) internal {
        int256 _response = HederaTokenService.transferToken(
            mingoToken,
            _from,
            _to,
            _amount
        );

        if (_response != HederaResponseCodes.SUCCESS) {
            revert("Transfer Failed");
        }
    }

    function mintTo(
        int64 _amount,
        address _receiver,
        address _tokenAddress,
        bytes[] memory _metadata
    ) internal returns (uint64, int64[] memory) {
        uint64 uIntAmount = uint64(_amount);
        // Mint new NFTs
        (
            int256 response,
            uint64 newTotalSupply,
            int64[] memory serialNumbers
        ) = HederaTokenService.mintToken(_tokenAddress, uIntAmount, _metadata);
        if (response != HederaResponseCodes.SUCCESS) {
            revert("Mint Failed");
        }

        // // Associate token
        // response = HederaTokenService.associateToken(_receiver, _tokenAddress);
        // if (response != HederaResponseCodes.SUCCESS) {
        //     revert("Mint Failed");
        // }
        // //Transfer NFT to _receiver
        // for (uint256 i; i < uint256(uint64(_amount)); ++i) {
        //     transferNFT(
        //         _tokenAddress,
        //         address(this),
        //         _receiver,
        //         serialNumbers[i]
        //     );
        // }
        return (newTotalSupply, serialNumbers);
    }
}
