//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./hip-206/HederaTokenService.sol";
import "./hip-206/HederaResponseCodes.sol";

contract Demo is HederaTokenService {
    address tokenAddress;

    constructor(address _tokenAddress) public {
        tokenAddress = _tokenAddress;
    }

    function mint(uint64 _amount) external {
        (
            int256 _response,
            uint64 newTotalSupply,
            int64[] memory serialNumbers
        ) = HederaTokenService.mintToken(tokenAddress, _amount, new bytes[](0));

        if (_response != HederaResponseCodes.SUCCESS) {
            revert("Mint Failed");
        }
    }

    function tokenAssociate() external {
        int256 response = HederaTokenService.associateToken(
            address(this),
            tokenAddress
        );

        if (response != HederaResponseCodes.SUCCESS) {
            revert("Associate Failed");
        }
    }

    function deposit() external {
        tokenTransfer(1, msg.sender, address(this));
    }

    function withdraw() external {
        tokenTransfer(1, address(this), msg.sender);
    }

    function tokenTransfer(
        int64 _amount,
        address _from,
        address _to
    ) internal {
        int256 _response = HederaTokenService.transferToken(
            tokenAddress,
            _from,
            _to,
            _amount
        );

        if (_response != HederaResponseCodes.SUCCESS) {
            revert("Transfer Failed");
        }
    }

    function mintFungibleToken(uint64 _amount) external {
        (
            int256 _response,
            uint64 newTotalSupply,
            int64[] memory serialNumbers
        ) = HederaTokenService.mintToken(tokenAddress, _amount, new bytes[](0));

        if (_response != HederaResponseCodes.SUCCESS) {
            revert("Mint Failed");
        }
    }
}
