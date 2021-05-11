// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0;
import "./SimpleStaking.sol";
import "../Interfaces.sol";


/**
 * @title Staking contract that donates earned interest to the DAO
 * allowing stakers to deposit DAI/ETH
 * or withdraw their stake in DAI
 * the contracts buy cDai and can transfer the daily interest to the  DAO
 */
contract GoodCompoundStaking is SimpleStaking {



    /**
    * @param _token Token to swap DEFI token
    * @param _iToken DEFI token address
    * @param _ns Address of the NameService
    * @param _tokenName Name of the staking token which will be provided to staker for their staking share
    * @param _tokenSymbol Symbol of the staking token which will be provided to staker for their staking share
    * @param _tokenSymbol Determines blocks to pass for 1x Multiplier
     */
    constructor(
        address _token,
        address _iToken,
        uint256 _blockInterval,
        NameService _ns,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint64 _maxRewardThreshold
    )  SimpleStaking(_token, _iToken, _blockInterval, _ns , _tokenName , _tokenSymbol, _maxRewardThreshold) {
        
    }

    /**
     * @dev stake some DAI
     * @param _amount of dai to stake
     */
    function mintInterestToken(uint256 _amount) internal override{
        
        cERC20 cToken = cERC20(address(iToken));
        uint res = cToken.mint(_amount);

        if (
            res > 0
        ) //cDAI returns >0 if error happened while minting. make sure no errors, if error return DAI funds
        {
            require(res == 0, "Minting cDai failed, funds returned");
        }

    }

    /**
     * @dev redeem DAI from compound 
     * @param _amount of dai to redeem
     */
    function redeem(uint256 _amount) internal override{
        cERC20 cToken = cERC20(address(iToken));
        require(cToken.redeemUnderlying(_amount) == 0, "Failed to redeem cDai");

    }

    /**
     * @dev returns Dai to cDai Exchange rate.
     */
    function exchangeRate() internal view override returns(uint) {
        cERC20 cToken = cERC20(address(iToken));
        return cToken.exchangeRateStored();

    }

    /**
     * @dev returns decimals of token.
     */
    function tokenDecimal() internal view override returns(uint) {
        ERC20 token = ERC20(address(token));
        return uint(token.decimals());
    }

    /**
     * @dev returns decimals of interest token.
     */
    function iTokenDecimal() internal view override returns(uint) {
        ERC20 cToken = ERC20(address(iToken));
        return uint(cToken.decimals());
    }

    function getGasCostForInterestTransfer() external view override returns(uint256){
        return uint256(67917);
    }
}