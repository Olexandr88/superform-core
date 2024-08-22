// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { DataLib } from "src/libraries/DataLib.sol";
import { SuperPositions } from "src/SuperPositions.sol";
import { Error } from "src/libraries/Error.sol";
import {
    BaseSuperformRouterPlus,
    SingleDirectSingleVaultStateReq,
    SingleDirectMultiVaultStateReq,
    SingleXChainSingleVaultStateReq,
    SingleXChainMultiVaultStateReq,
    MultiDstMultiVaultStateReq,
    MultiDstSingleVaultStateReq
} from "src/router-plus/BaseSuperformRouterPlus.sol";
import { IBaseStateRegistry } from "src/interfaces/IBaseStateRegistry.sol";
import { IBaseRouter } from "src/interfaces/IBaseRouter.sol";
import { ISuperformRouterPlus, IERC20 } from "src/interfaces/ISuperformRouterPlus.sol";
import { ISuperformRouterPlusAsync } from "src/interfaces/ISuperformRouterPlusAsync.sol";

/// @title SuperformRouterPlus
/// @dev Performs rebalances and deposits on the Superform platform
/// @author Zeropoint Labs
contract SuperformRouterPlus is ISuperformRouterPlus, BaseSuperformRouterPlus {
    using DataLib for uint256;
    using SafeERC20 for IERC20;

    //////////////////////////////////////////////////////////////
    //                      CONSTRUCTOR                         //
    //////////////////////////////////////////////////////////////

    constructor(
        address superRegistry_,
        address superformRouter_,
        address superPositions_,
        IBaseStateRegistry coreStateRegistry_
    )
        BaseSuperformRouterPlus(superRegistry_, superformRouter_, superPositions_, coreStateRegistry_)
    { }

    //////////////////////////////////////////////////////////////
    //                  EXTERNAL WRITE FUNCTIONS                //
    //////////////////////////////////////////////////////////////

    /// @inheritdoc ISuperformRouterPlus
    function rebalanceSinglePosition(RebalanceSinglePositionSyncArgs calldata args) external payable override {
        (uint256 balanceBefore, uint256 totalFee) = _beforeRebalanceChecks(
            args.interimAsset, args.receiverAddressSP, args.rebalanceFromMsgValue, args.rebalanceToMsgValue
        );

        /// @dev transfers a single superPosition to this contract and approves router
        _transferSuperPositions(args.receiverAddressSP, args.id, args.sharesToRedeem);

        _rebalancePositionsSync(
            RebalancePositionsSyncArgs(
                Actions.REBALANCE_FROM_SINGLE,
                args.previewRedeemAmount,
                args.interimAsset,
                args.slippage,
                args.rebalanceFromMsgValue,
                args.rebalanceToMsgValue,
                args.receiverAddressSP,
                args.smartWallet
            ),
            args.callData,
            args.rebalanceCallData,
            balanceBefore
        );

        _refundUnused(args.interimAsset, args.receiverAddressSP, balanceBefore, totalFee);

        emit RebalanceSyncCompleted(args.receiverAddressSP, args.id, args.sharesToRedeem, args.smartWallet);
    }

    /// @inheritdoc ISuperformRouterPlus
    function rebalanceMultiPositions(RebalanceMultiPositionsSyncArgs calldata args) external payable override {
        (uint256 balanceBefore, uint256 totalFee) = _beforeRebalanceChecks(
            args.interimAsset, args.receiverAddressSP, args.rebalanceFromMsgValue, args.rebalanceToMsgValue
        );

        if (args.ids.length != args.sharesToRedeem.length) {
            revert Error.ARRAY_LENGTH_MISMATCH();
        }

        /// @dev transfers multiple superPositions to this contract and approves router
        _transferBatchSuperPositions(args.receiverAddressSP, args.ids, args.sharesToRedeem);

        _rebalancePositionsSync(
            RebalancePositionsSyncArgs(
                Actions.REBALANCE_FROM_MULTI,
                args.previewRedeemAmount,
                args.interimAsset,
                args.slippage,
                args.rebalanceFromMsgValue,
                args.rebalanceToMsgValue,
                args.receiverAddressSP,
                args.smartWallet
            ),
            args.callData,
            args.rebalanceCallData,
            balanceBefore
        );

        _refundUnused(args.interimAsset, args.receiverAddressSP, balanceBefore, totalFee);

        emit RebalanceMultiSyncCompleted(args.receiverAddressSP, args.ids, args.sharesToRedeem, args.smartWallet);
    }

    /// @inheritdoc ISuperformRouterPlus
    function startCrossChainRebalance(InitiateXChainRebalanceArgs calldata args) external payable override {
        if (
            args.rebalanceToAmbIds.length == 0 || args.rebalanceToDstChainIds.length == 0
                || args.rebalanceToSfData.length == 0
        ) {
            revert EMPTY_REBALANCE_CALL_DATA();
        }

        if (args.interimAsset == address(0) || args.receiverAddressSP == address(0)) {
            revert Error.ZERO_ADDRESS();
        }

        if (args.expectedAmountInterimAsset == 0) {
            revert Error.ZERO_AMOUNT();
        }

        /// @dev transfers a single superPosition to this contract and approves router
        _transferSuperPositions(args.receiverAddressSP, args.id, args.sharesToRedeem);

        if (!whitelistedSelectors[Actions.REBALANCE_X_CHAIN_FROM_SINGLE][_parseSelectorMem(args.callData)]) {
            revert INVALID_REBALANCE_FROM_SELECTOR();
        }

        /// @dev validate the call data

        SingleXChainSingleVaultStateReq memory req =
            abi.decode(_parseCallData(args.callData), (SingleXChainSingleVaultStateReq));

        if (req.superformData.liqRequest.token != args.interimAsset) {
            revert REBALANCE_SINGLE_POSITIONS_DIFFERENT_TOKEN();
        }

        if (req.superformData.liqRequest.liqDstChainId != CHAIN_ID) {
            revert REBALANCE_SINGLE_POSITIONS_DIFFERENT_CHAIN();
        }

        address ROUTER_PLUS_ASYNC = _getAddress(keccak256("SUPERFORM_ROUTER_PLUS_ASYNC"));

        if (req.superformData.receiverAddress != ROUTER_PLUS_ASYNC) {
            revert REBALANCE_XCHAIN_INVALID_RECEIVER_ADDRESS();
        }

        /// @dev send SPs to router
        /// @notice msg.value here is the sum of rebalanceFromMsgValue and rebalanceToMsgValue (to be executed later by
        /// the keeper)
        _callSuperformRouter(args.callData, msg.value);

        if (!whitelistedSelectors[Actions.DEPOSIT][args.rebalanceToSelector]) {
            revert INVALID_REBALANCE_TO_SELECTOR();
        }

        ISuperformRouterPlusAsync(ROUTER_PLUS_ASYNC).setXChainRebalanceCallData(
            args.receiverAddressSP,
            CORE_STATE_REGISTRY.payloadsCount(),
            XChainRebalanceData({
                rebalanceSelector: args.rebalanceToSelector,
                smartWallet: args.smartWallet,
                interimAsset: args.interimAsset,
                slippage: args.finalizeSlippage,
                expectedAmountInterimAsset: args.expectedAmountInterimAsset,
                rebalanceToAmbIds: args.rebalanceToAmbIds,
                rebalanceToDstChainIds: args.rebalanceToDstChainIds,
                rebalanceToSfData: args.rebalanceToSfData
            })
        );

        emit XChainRebalanceInitiated(
            args.receiverAddressSP,
            args.id,
            args.sharesToRedeem,
            args.smartWallet,
            args.interimAsset,
            args.finalizeSlippage,
            args.expectedAmountInterimAsset,
            args.rebalanceToSelector
        );
    }

    /// @inheritdoc ISuperformRouterPlus
    function startCrossChainRebalanceMulti(InitiateXChainRebalanceMultiArgs calldata args) external payable override {
        if (args.ids.length != args.sharesToRedeem.length) {
            revert Error.ARRAY_LENGTH_MISMATCH();
        }

        if (
            args.rebalanceToAmbIds.length == 0 || args.rebalanceToDstChainIds.length == 0
                || args.rebalanceToSfData.length == 0
        ) {
            revert EMPTY_REBALANCE_CALL_DATA();
        }

        if (args.interimAsset == address(0) || args.receiverAddressSP == address(0)) {
            revert Error.ZERO_ADDRESS();
        }

        if (args.expectedAmountInterimAsset == 0) {
            revert Error.ZERO_AMOUNT();
        }

        /// @dev transfers multiple superPositions to this contract and approves router
        _transferBatchSuperPositions(args.receiverAddressSP, args.ids, args.sharesToRedeem);

        /// @dev validate the call data

        bytes4 selector = _parseSelectorMem(args.callData);

        if (!whitelistedSelectors[Actions.REBALANCE_X_CHAIN_FROM_MULTI][selector]) {
            revert INVALID_REBALANCE_FROM_SELECTOR();
        }

        address ROUTER_PLUS_ASYNC = _getAddress(keccak256("SUPERFORM_ROUTER_PLUS_ASYNC"));

        if (selector == IBaseRouter.singleXChainMultiVaultWithdraw.selector) {
            SingleXChainMultiVaultStateReq memory req =
                abi.decode(_parseCallData(args.callData), (SingleXChainMultiVaultStateReq));

            uint256 len = req.superformsData.liqRequests.length;

            for (uint256 i; i < len; ++i) {
                // Validate that the token and chainId is equal in all indexes
                if (req.superformsData.liqRequests[i].token != args.interimAsset) {
                    revert REBALANCE_MULTI_POSITIONS_DIFFERENT_TOKEN();
                }
                if (req.superformsData.liqRequests[i].liqDstChainId != CHAIN_ID) {
                    revert REBALANCE_MULTI_POSITIONS_DIFFERENT_CHAIN();
                }
            }

            if (req.superformsData.receiverAddress != ROUTER_PLUS_ASYNC) {
                revert REBALANCE_XCHAIN_INVALID_RECEIVER_ADDRESS();
            }
        } else if (selector == IBaseRouter.multiDstMultiVaultWithdraw.selector) {
            MultiDstMultiVaultStateReq memory req =
                abi.decode(_parseCallData(args.callData), (MultiDstMultiVaultStateReq));

            uint256 len = req.superformsData.length;

            for (uint256 i; i < len; ++i) {
                uint256 len2 = req.superformsData[i].liqRequests.length;

                for (uint256 j; j < len2; ++j) {
                    // Validate that the token and chainId is equal in all indexes
                    if (req.superformsData[i].liqRequests[j].token != args.interimAsset) {
                        revert REBALANCE_MULTI_POSITIONS_DIFFERENT_TOKEN();
                    }
                    if (req.superformsData[i].liqRequests[j].liqDstChainId != CHAIN_ID) {
                        revert REBALANCE_MULTI_POSITIONS_DIFFERENT_CHAIN();
                    }
                }

                if (req.superformsData[i].receiverAddress != ROUTER_PLUS_ASYNC) {
                    revert REBALANCE_XCHAIN_INVALID_RECEIVER_ADDRESS();
                }
            }
        } else if (selector == IBaseRouter.multiDstSingleVaultWithdraw.selector) {
            MultiDstSingleVaultStateReq memory req =
                abi.decode(_parseCallData(args.callData), (MultiDstSingleVaultStateReq));

            uint256 len = req.superformsData.length;

            for (uint256 i; i < len; ++i) {
                // Validate that the token and chainId is equal in all indexes
                if (req.superformsData[i].liqRequest.token != args.interimAsset) {
                    revert REBALANCE_MULTI_POSITIONS_DIFFERENT_TOKEN();
                }
                if (req.superformsData[i].liqRequest.liqDstChainId != CHAIN_ID) {
                    revert REBALANCE_MULTI_POSITIONS_DIFFERENT_CHAIN();
                }

                if (req.superformsData[i].receiverAddress != ROUTER_PLUS_ASYNC) {
                    revert REBALANCE_XCHAIN_INVALID_RECEIVER_ADDRESS();
                }
            }
        }

        /// @dev send SPs to router
        _callSuperformRouter(args.callData, msg.value);

        if (!whitelistedSelectors[Actions.DEPOSIT][args.rebalanceToSelector]) {
            revert INVALID_REBALANCE_TO_SELECTOR();
        }

        /// @dev in multiDst multiple payloads ids will be generated on source chain
        ISuperformRouterPlusAsync(ROUTER_PLUS_ASYNC).setXChainRebalanceCallData(
            args.receiverAddressSP,
            CORE_STATE_REGISTRY.payloadsCount(),
            XChainRebalanceData({
                rebalanceSelector: args.rebalanceToSelector,
                smartWallet: args.smartWallet,
                interimAsset: args.interimAsset,
                slippage: args.finalizeSlippage,
                expectedAmountInterimAsset: args.expectedAmountInterimAsset,
                rebalanceToAmbIds: args.rebalanceToAmbIds,
                rebalanceToDstChainIds: args.rebalanceToDstChainIds,
                rebalanceToSfData: args.rebalanceToSfData
            })
        );

        emit XChainRebalanceMultiInitiated(
            args.receiverAddressSP,
            args.ids,
            args.sharesToRedeem,
            args.smartWallet,
            args.interimAsset,
            args.finalizeSlippage,
            args.expectedAmountInterimAsset,
            args.rebalanceToSelector
        );
    }

    /// @inheritdoc ISuperformRouterPlus
    function deposit4626(
        address vault_,
        uint256 amount_,
        address receiverAddressSP_,
        bool smartWallet_,
        bytes calldata callData_
    )
        external
        payable
        override
    {
        _transferERC20In(IERC20(vault_), receiverAddressSP_, amount_);
        IERC4626 vault = IERC4626(vault_);
        uint256 amountRedeemed = _redeemShare(vault, amount_);

        IERC20 asset = IERC20(vault.asset());

        if (!whitelistedSelectors[Actions.DEPOSIT][_parseSelectorMem(callData_)]) {
            revert INVALID_REBALANCE_TO_SELECTOR();
        }

        smartWallet_
            ? _depositUsingSmartWallet(asset, amountRedeemed, msg.value, receiverAddressSP_, callData_)
            : _deposit(asset, amountRedeemed, msg.value, callData_);

        emit Deposit4626Completed(receiverAddressSP_, vault_);
    }

    /// @inheritdoc ISuperformRouterPlus
    function deposit(
        IERC20 asset_,
        uint256 amount_,
        address receiverAddressSP_,
        bool smartWallet_,
        bytes calldata callData_
    )
        public
        payable
        override
    {
        _transferERC20In(asset_, receiverAddressSP_, amount_);

        if (!whitelistedSelectors[Actions.DEPOSIT][_parseSelectorMem(callData_)]) {
            revert INVALID_REBALANCE_TO_SELECTOR();
        }

        smartWallet_
            ? _depositUsingSmartWallet(asset_, amount_, msg.value, receiverAddressSP_, callData_)
            : _deposit(asset_, amount_, msg.value, callData_);

        emit DepositCompleted(receiverAddressSP_, smartWallet_, false);
    }

    //////////////////////////////////////////////////////////////
    //                   INTERNAL FUNCTIONS                     //
    //////////////////////////////////////////////////////////////

    function _rebalancePositionsSync(
        RebalancePositionsSyncArgs memory args,
        bytes calldata callData,
        bytes calldata rebalanceCallData,
        uint256 balanceBefore
    )
        internal
    {
        IERC20 asset = IERC20(args.asset);

        /// @dev validate the call data
        if (!whitelistedSelectors[args.action][_parseSelectorMem(callData)]) {
            revert INVALID_REBALANCE_FROM_SELECTOR();
        }

        if (args.action == Actions.REBALANCE_FROM_SINGLE) {
            SingleDirectSingleVaultStateReq memory req =
                abi.decode(_parseCallData(callData), (SingleDirectSingleVaultStateReq));

            if (req.superformData.liqRequest.token != args.asset) {
                revert REBALANCE_SINGLE_POSITIONS_DIFFERENT_TOKEN();
            }
            if (req.superformData.liqRequest.liqDstChainId != CHAIN_ID) {
                revert REBALANCE_SINGLE_POSITIONS_DIFFERENT_CHAIN();
            }
        } else {
            SingleDirectMultiVaultStateReq memory req =
                abi.decode(_parseCallData(callData), (SingleDirectMultiVaultStateReq));
            uint256 len = req.superformData.liqRequests.length;

            for (uint256 i; i < len; ++i) {
                // Validate that the token and chainId is equal in all indexes
                if (req.superformData.liqRequests[i].token != args.asset) {
                    revert REBALANCE_MULTI_POSITIONS_DIFFERENT_TOKEN();
                }
                if (req.superformData.liqRequests[i].liqDstChainId != CHAIN_ID) {
                    revert REBALANCE_MULTI_POSITIONS_DIFFERENT_CHAIN();
                }
            }
        }

        /// @dev send SPs to router
        _callSuperformRouter(callData, args.rebalanceFromMsgValue);

        uint256 amountToDeposit = asset.balanceOf(address(this)) - balanceBefore;

        if (amountToDeposit == 0) revert Error.ZERO_AMOUNT();

        if (ENTIRE_SLIPPAGE * amountToDeposit < ((args.previewRedeemAmount * (ENTIRE_SLIPPAGE - args.slippage)))) {
            revert Error.VAULT_IMPLEMENTATION_FAILED();
        }

        /// @dev step 3: rebalance into a new superform with rebalanceCallData
        if (!whitelistedSelectors[Actions.DEPOSIT][_parseSelectorMem(rebalanceCallData)]) {
            revert INVALID_REBALANCE_TO_SELECTOR();
        }

        args.smartWallet
            ? _depositUsingSmartWallet(
                asset, amountToDeposit, args.rebalanceToMsgValue, args.receiverAddressSP, rebalanceCallData
            )
            : _deposit(asset, amountToDeposit, args.rebalanceToMsgValue, rebalanceCallData);
    }

    function _transferSuperPositions(address user_, uint256 id_, uint256 amount_) internal {
        SuperPositions(SUPER_POSITIONS).safeTransferFrom(user_, address(this), id_, amount_, "");
        SuperPositions(SUPER_POSITIONS).setApprovalForOne(SUPERFORM_ROUTER, id_, amount_);
    }

    function _transferBatchSuperPositions(address user_, uint256[] memory ids_, uint256[] memory amounts_) internal {
        SuperPositions(SUPER_POSITIONS).safeBatchTransferFrom(user_, address(this), ids_, amounts_, "");
        SuperPositions(SUPER_POSITIONS).setApprovalForAll(SUPERFORM_ROUTER, true);
    }

    function _transferERC20In(IERC20 erc20_, address user_, uint256 amount_) internal {
        erc20_.transferFrom(user_, address(this), amount_);
    }

    function _redeemShare(IERC4626 vault_, uint256 amountToRedeem_) internal returns (uint256 balanceDifference) {
        IERC20 asset = IERC20(vault_.asset());
        uint256 collateralBalanceBefore = asset.balanceOf(address(this));

        /// @dev redeem the vault shares and receive collateral
        vault_.redeem(amountToRedeem_, address(this), address(this));

        /// @dev collateral balance after
        uint256 collateralBalanceAfter = asset.balanceOf(address(this));

        balanceDifference = collateralBalanceAfter - collateralBalanceBefore;
    }

    /// @dev helps parse bytes memory selector
    function _parseSelectorMem(bytes memory data) internal pure returns (bytes4 selector) {
        assembly {
            selector := mload(add(data, 0x20))
        }
    }

    /// @dev helps parse calldata
    function _parseCallData(bytes calldata callData_) internal pure returns (bytes calldata) {
        return callData_[4:];
    }

    function _beforeRebalanceChecks(
        address asset_,
        address user_,
        uint256 rebalanceFromMsgValue_,
        uint256 rebalanceToMsgValue_
    )
        internal
        returns (uint256 balanceBefore, uint256 totalFee)
    {
        if (asset_ == address(0) || user_ == address(0)) {
            revert Error.ZERO_ADDRESS();
        }

        balanceBefore = IERC20(asset_).balanceOf(address(this));

        totalFee = rebalanceFromMsgValue_ + rebalanceToMsgValue_;

        if (msg.value < totalFee) {
            revert INVALID_FEE();
        }
    }

    /// @dev refunds any unused refunds
    function _refundUnused(address asset_, address user_, uint256 balanceBefore, uint256 totalFee) internal {
        uint256 balanceDiff = IERC20(asset_).balanceOf(address(this)) - balanceBefore;

        if (balanceDiff > 0) {
            IERC20(asset_).transfer(user_, balanceDiff);
        }

        if (msg.value > totalFee) {
            /// @dev refunds msg.sender if msg.value was more than needed
            (bool success,) = payable(msg.sender).call{ value: msg.value - totalFee }("");

            if (!success) {
                revert Error.FAILED_TO_SEND_NATIVE();
            }
        }
    }
}
