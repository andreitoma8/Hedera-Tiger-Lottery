//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./hip-206/HederaTokenService.sol";

contract TigerLottery is HederaTokenService {
    address tokenAddress;

    function setToken(address _tokenAddress) external {
        tokenAddress = _tokenAddress;
    }

    function mint(int64 _amount, bytes[] memory _metadata) external {
        mintTo(_amount, msg.sender, tokenAddress, _metadata);
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

        // Associate token
        response = HederaTokenService.associateToken(_receiver, _tokenAddress);
        if (response != HederaResponseCodes.SUCCESS) {
            revert("Mint Failed");
        }
        // Transfer NFT to _receiver
        for (uint256 i; i < uint256(uint64(_amount)); ++i) {
            transferNFT(
                _tokenAddress,
                address(this),
                _receiver,
                serialNumbers[i]
            );
        }
        return (newTotalSupply, serialNumbers);
    }
}
