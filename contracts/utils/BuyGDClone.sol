// SPDX-License-Identifier: MIT

pragma solidity >=0.8;
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@mean-finance/uniswap-v3-oracle/solidity/interfaces/IStaticOracle.sol";
import "../Interfaces.sol";

// @uniswap/v3-core
interface ISwapRouter {
	struct ExactInputSingleParams {
		address tokenIn;
		address tokenOut;
		uint24 fee;
		address recipient;
		uint256 amountIn;
		uint256 amountOutMinimum;
		uint160 sqrtPriceLimitX96;
	}

	/// @notice Swaps `amountIn` of one token for as much as possible of another token
	/// @dev Setting `amountIn` to 0 will cause the contract to look up its own balance,
	/// and swap the entire amount, enabling contracts to send tokens before calling this function.
	/// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
	/// @return amountOut The amount of the received token
	function exactInputSingle(
		ExactInputSingleParams calldata params
	) external payable returns (uint256 amountOut);

	struct ExactInputParams {
		bytes path;
		address recipient;
		uint256 amountIn;
		uint256 amountOutMinimum;
	}

	/// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
	/// @dev Setting `amountIn` to 0 will cause the contract to look up its own balance,
	/// and swap the entire amount, enabling contracts to send tokens before calling this function.
	/// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
	/// @return amountOut The amount of the received token
	function exactInput(
		ExactInputParams calldata params
	) external payable returns (uint256 amountOut);

	struct ExactOutputSingleParams {
		address tokenIn;
		address tokenOut;
		uint24 fee;
		address recipient;
		uint256 amountOut;
		uint256 amountInMaximum;
		uint160 sqrtPriceLimitX96;
	}

	/// @notice Swaps as little as possible of one token for `amountOut` of another token
	/// that may remain in the router after the swap.
	/// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
	/// @return amountIn The amount of the input token
	function exactOutputSingle(
		ExactOutputSingleParams calldata params
	) external payable returns (uint256 amountIn);

	struct ExactOutputParams {
		bytes path;
		address recipient;
		uint256 amountOut;
		uint256 amountInMaximum;
	}

	/// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
	/// that may remain in the router after the swap.
	/// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
	/// @return amountIn The amount of the input token
	function exactOutput(
		ExactOutputParams calldata params
	) external payable returns (uint256 amountIn);
}

/*
 * @title BuyGDClone
 * @notice This contract allows users to swap Celo or cUSD for GoodDollar (GD) tokens.
 * @dev This contract is a clone of the BuyGD contract, which is used to buy GD tokens on the GoodDollar platform.
 * @dev This contract uses the SwapRouter contract to perform the swaps.
 */
contract BuyGDClone is Initializable {
	error REFUND_FAILED(uint256);
	error NO_BALANCE();

	ISwapRouter public immutable router;
	address public constant celo = 0x471EcE3750Da237f93B8E339c536989b8978a438;
	uint32 public immutable twapPeriod;
	address public immutable cusd;
	address public immutable gd;
	IStaticOracle public immutable oracle;

	address public owner;

	receive() external payable {}

	constructor(
		ISwapRouter _router,
		address _cusd,
		address _gd,
		IStaticOracle _oracle
	) {
		router = _router;
		cusd = _cusd;
		gd = _gd;
		oracle = _oracle;
		twapPeriod = 300; //5 minutes
	}

	/**
	 * @notice Initializes the contract with the owner's address.
	 * @param _owner The address of the owner of the contract.
	 */
	function initialize(address _owner) external initializer {
		owner = _owner;
	}

	/**
	 * @notice Swaps either Celo or cUSD for GD tokens.
	 * @dev If the contract has a balance of Celo, it will swap Celo for GD tokens.
	 * @dev If the contract has a balance of cUSD, it will swap cUSD for GD tokens.
	 * @param _minAmount The minimum amount of GD tokens to receive from the swap.
	 */
	function swap(
		uint256 _minAmount,
		address payable refundGas
	) external payable {
		uint256 balance = address(this).balance;
		if (balance > 0) return swapCelo(_minAmount, refundGas);

		balance = ERC20(cusd).balanceOf(address(this));
		if (balance > 0) return swapCusd(_minAmount, refundGas);

		revert NO_BALANCE();
	}

	/**
	 * @notice Swaps Celo for GD tokens.
	 * @param _minAmount The minimum amount of GD tokens to receive from the swap.
	 */
	function swapCelo(
		uint256 _minAmount,
		address payable refundGas
	) public payable {
		uint256 gasCosts;
		if (refundGas != owner) {
			(gasCosts, ) = oracle.quoteAllAvailablePoolsWithTimePeriod(
				1e17, //0.1$
				cusd,
				celo,
				60
			);
		}

		uint256 amountIn = address(this).balance - gasCosts;

		(uint256 minByTwap, ) = minAmountByTWAP(amountIn, celo, twapPeriod);
		_minAmount = _minAmount > minByTwap ? _minAmount : minByTwap;

		ERC20(celo).approve(address(router), amountIn);
		ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
			path: abi.encodePacked(celo, uint24(3000), cusd, uint24(10000), gd),
			recipient: owner,
			amountIn: amountIn,
			amountOutMinimum: _minAmount
		});
		router.exactInput(params);
		if (refundGas != owner) {
			(bool sent, ) = refundGas.call{ value: gasCosts }("");
			if (!sent) revert REFUND_FAILED(gasCosts);
		}
	}

	/**
	 * @notice Swaps cUSD for GD tokens.
	 * @param _minAmount The minimum amount of GD tokens to receive from the swap.
	 */
	function swapCusd(uint256 _minAmount, address refundGas) public {
		uint256 gasCosts = refundGas != owner ? 1e17 : 0; //fixed 0.1$
		uint256 amountIn = ERC20(cusd).balanceOf(address(this)) - gasCosts;

		(uint256 minByTwap, ) = minAmountByTWAP(amountIn, cusd, twapPeriod);
		_minAmount = _minAmount > minByTwap ? _minAmount : minByTwap;

		ERC20(cusd).approve(address(router), amountIn);
		ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
			path: abi.encodePacked(cusd, uint24(10000), gd),
			recipient: owner,
			amountIn: amountIn,
			amountOutMinimum: _minAmount
		});
		router.exactInput(params);
		if (refundGas != owner) {
			ERC20(cusd).transfer(refundGas, gasCosts);
		}
	}

	/**
	 * @notice Calculates the minimum amount of tokens that can be received for a given amount of base tokens,
	 * based on the time-weighted average price (TWAP) of the token pair over a specified period of time.
	 * @param baseAmount The amount of base tokens to swap.
	 * @param baseToken The address of the base token.
	 * @return minTwap The minimum amount of G$ expected to receive by twap
	 */
	function minAmountByTWAP(
		uint256 baseAmount,
		address baseToken,
		uint32 period
	) public view returns (uint256 minTwap, uint256 quote) {
		uint128 toConvert = uint128(baseAmount);
		if (baseToken == celo) {
			(quote, ) = oracle.quoteAllAvailablePoolsWithTimePeriod(
				toConvert,
				baseToken,
				cusd,
				period
			);
			toConvert = uint128(quote);
		}
		(quote, ) = oracle.quoteAllAvailablePoolsWithTimePeriod(
			toConvert,
			cusd,
			gd,
			period
		);
		//minAmount should not be 2% under twap (ie we dont expect price movement > 2% in timePeriod)
		return ((quote * 98) / 100, quote);
	}

	/**
	 * @notice Recovers tokens accidentally sent to the contract.
	 * @param token The address of the token to recover. Use address(0) to recover ETH.
	 */
	function recover(address token) external {
		if (token == address(0)) {
			(bool sent, ) = payable(owner).call{ value: address(this).balance }("");
			if (!sent) revert REFUND_FAILED(address(this).balance);
		} else {
			ERC20(token).transfer(owner, ERC20(token).balanceOf(address(this)));
		}
	}
}

/**
 * @title BuyGDCloneFactory
 * @notice Factory contract for creating clones of BuyGDClone contract
 */
contract BuyGDCloneFactory {
	address public immutable impl;

	/**
	 * @notice Initializes the BuyGDCloneFactory contract with the provided parameters.
	 * @param _router The address of the SwapRouter contract.
	 * @param _cusd The address of the cUSD token contract.
	 * @param _gd The address of the GD token contract.
	 * @param _oracle The address of the StaticOracle contract.
	 */
	constructor(
		ISwapRouter _router,
		address _cusd,
		address _gd,
		IStaticOracle _oracle
	) {
		impl = address(new BuyGDClone(_router, _cusd, _gd, _oracle));
		_oracle.prepareAllAvailablePoolsWithTimePeriod(_gd, _cusd, 600);
	}

	/**
	 * @notice Creates a new clone of the BuyGDClone contract with the provided owner address.
	 * @param owner The address of the owner of the new BuyGDClone contract.
	 * @return The address of the new BuyGDClone contract.
	 */
	function create(address owner) external returns (address) {
		bytes32 salt = keccak256(abi.encode(owner));
		address clone = ClonesUpgradeable.cloneDeterministic(impl, salt);
		BuyGDClone(payable(clone)).initialize(owner);
		return clone;
	}

	function createAndSwap(
		address owner,
		uint256 minAmount
	) external returns (address) {
		bytes32 salt = keccak256(abi.encode(owner));
		address clone = ClonesUpgradeable.cloneDeterministic(impl, salt);
		BuyGDClone(payable(clone)).initialize(owner);
		BuyGDClone(payable(clone)).swap(minAmount, payable(msg.sender));
		return clone;
	}

	/**
	 * @notice Predicts the address of a new clone of the BuyGDClone contract with the provided owner address.
	 * @param owner The address of the owner of the new BuyGDClone contract.
	 * @return The predicted address of the new BuyGDClone contract.
	 */
	function predict(address owner) external view returns (address) {
		bytes32 salt = keccak256(abi.encode(owner));

		return
			ClonesUpgradeable.predictDeterministicAddress(impl, salt, address(this));
	}

	function getBaseFee() external view returns (uint256) {
		return block.basefee;
	}
}
