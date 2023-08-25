// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import { ISuperPositions } from "../../interfaces/ISuperPositions.sol";
import { IBaseStateRegistry } from "../../interfaces/IBaseStateRegistry.sol";
import { ITwoStepsFormStateRegistry } from "../../interfaces/ITwoStepsFormStateRegistry.sol";
import { IPayloadHelper } from "../../interfaces/IPayloadHelper.sol";
import {
    CallbackType,
    ReturnMultiData,
    ReturnSingleData,
    InitMultiVaultData,
    InitSingleVaultData,
    TwoStepsPayload,
    LiqRequest
} from "../../types/DataTypes.sol";
import { DataLib } from "../../libraries/DataLib.sol";

/// @title PayloadHelper
/// @author ZeroPoint Labs
/// @dev helps decode payload data more easily. Used for off-chain purposes
contract PayloadHelper is IPayloadHelper {
    using DataLib for uint256;

    /*///////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct DecodeDstPayloadInternalVars {
        uint8 txType;
        uint8 callbackType;
        address srcSender;
        uint64 srcChainId;
        uint256[] amounts;
        uint256[] slippage;
        uint256[] superformIds;
        uint256 srcPayloadId;
        uint8 multi;
        ReturnMultiData rd;
        ReturnSingleData rsd;
        InitMultiVaultData imvd;
        InitSingleVaultData isvd;
    }

    struct DecodeDstPayloadLiqDataInternalVars {
        uint8 callbackType;
        uint8 multi;
        uint8[] bridgeIds;
        bytes[] txDatas;
        address[] liqDataTokens;
        uint256[] liqDataAmounts;
        uint256[] liqDataNativeAmounts;
        bytes[] permit2datas;
        InitMultiVaultData imvd;
        InitSingleVaultData isvd;
        uint256 i;
    }

    /*///////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IBaseStateRegistry public immutable dstPayloadRegistry;
    ISuperPositions public immutable srcPayloadRegistry;
    ITwoStepsFormStateRegistry public immutable twoStepRegistry;

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address dstPayloadRegistry_, address srcPayloadRegistry_, address twoStepRegistry_) {
        dstPayloadRegistry = IBaseStateRegistry(dstPayloadRegistry_);
        srcPayloadRegistry = ISuperPositions(srcPayloadRegistry_);
        twoStepRegistry = ITwoStepsFormStateRegistry(twoStepRegistry_);
    }

    /*///////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPayloadHelper
    function decodeDstPayload(uint256 dstPayloadId_)
        external
        view
        override
        returns (
            uint8 txType,
            uint8 callbackType,
            address srcSender,
            uint64 srcChainId,
            uint256[] memory amounts,
            uint256[] memory slippage,
            uint256[] memory superformIds,
            uint256 srcPayloadId
        )
    {
        DecodeDstPayloadInternalVars memory v;

        (v.txType, v.callbackType, v.multi,, v.srcSender, v.srcChainId) =
            dstPayloadRegistry.payloadHeader(dstPayloadId_).decodeTxInfo();

        if (v.callbackType == uint256(CallbackType.RETURN) || v.callbackType == uint256(CallbackType.FAIL)) {
            if (v.multi == 1) {
                v.rd = abi.decode(dstPayloadRegistry.payloadBody(dstPayloadId_), (ReturnMultiData));
                v.amounts = v.rd.amounts;
                v.srcPayloadId = v.rd.payloadId;
            } else {
                v.rsd = abi.decode(dstPayloadRegistry.payloadBody(dstPayloadId_), (ReturnSingleData));
                v.amounts = new uint256[](1);
                v.amounts[0] = v.rsd.amount;

                v.srcPayloadId = v.rsd.payloadId;
            }
        }

        if (v.callbackType == uint256(CallbackType.INIT)) {
            if (v.multi == 1) {
                v.imvd = abi.decode(dstPayloadRegistry.payloadBody(dstPayloadId_), (InitMultiVaultData));
                v.amounts = v.imvd.amounts;
                v.slippage = v.imvd.maxSlippage;
                v.superformIds = v.imvd.superformIds;
                v.srcPayloadId = v.imvd.payloadId;
            } else {
                v.isvd = abi.decode(dstPayloadRegistry.payloadBody(dstPayloadId_), (InitSingleVaultData));

                v.amounts = new uint256[](1);
                v.amounts[0] = v.isvd.amount;

                v.slippage = new uint256[](1);
                v.slippage[0] = v.isvd.maxSlippage;

                v.superformIds = new uint256[](1);
                v.superformIds[0] = v.isvd.superformId;

                v.srcPayloadId = v.isvd.payloadId;
            }
        }

        return
            (v.txType, v.callbackType, v.srcSender, v.srcChainId, v.amounts, v.slippage, v.superformIds, v.srcPayloadId);
    }

    /// @inheritdoc IPayloadHelper
    function decodeDstPayloadLiqData(uint256 dstPayloadId_)
        external
        view
        override
        returns (
            uint8[] memory bridgeIds,
            bytes[] memory txDatas,
            address[] memory tokens,
            uint256[] memory amounts,
            uint256[] memory nativeAmounts,
            bytes[] memory permit2datas
        )
    {
        DecodeDstPayloadLiqDataInternalVars memory v;

        (, v.callbackType, v.multi,,,) = dstPayloadRegistry.payloadHeader(dstPayloadId_).decodeTxInfo();

        if (v.multi == 1) {
            v.imvd = abi.decode(dstPayloadRegistry.payloadBody(dstPayloadId_), (InitMultiVaultData));

            v.bridgeIds = new uint8[](v.imvd.liqData.length);
            v.txDatas = new bytes[](v.imvd.liqData.length);
            v.liqDataTokens = new address[](v.imvd.liqData.length);
            v.liqDataAmounts = new uint256[](v.imvd.liqData.length);
            v.liqDataNativeAmounts = new uint256[](v.imvd.liqData.length);
            v.permit2datas = new bytes[](v.imvd.liqData.length);

            for (v.i; v.i < v.imvd.liqData.length; v.i++) {
                v.bridgeIds[v.i] = v.imvd.liqData[v.i].bridgeId;
                v.txDatas[v.i] = v.imvd.liqData[v.i].txData;
                v.liqDataTokens[v.i] = v.imvd.liqData[v.i].token;
                v.liqDataAmounts[v.i] = v.imvd.liqData[v.i].amount;
                v.liqDataNativeAmounts[v.i] = v.imvd.liqData[v.i].nativeAmount;
                v.permit2datas[v.i] = v.imvd.liqData[v.i].permit2data;
            }
        } else {
            v.isvd = abi.decode(dstPayloadRegistry.payloadBody(dstPayloadId_), (InitSingleVaultData));

            v.bridgeIds = new uint8[](1);
            v.bridgeIds[0] = v.isvd.liqData.bridgeId;

            v.txDatas = new bytes[](1);
            v.txDatas[0] = v.isvd.liqData.txData;

            v.liqDataTokens = new address[](1);
            v.liqDataTokens[0] = v.isvd.liqData.token;

            v.liqDataAmounts = new uint256[](1);
            v.liqDataAmounts[0] = v.isvd.liqData.amount;

            v.liqDataNativeAmounts = new uint256[](1);
            v.liqDataNativeAmounts[0] = v.isvd.liqData.nativeAmount;

            v.permit2datas = new bytes[](1);
            v.permit2datas[0] = v.isvd.liqData.permit2data;
        }

        return (v.bridgeIds, v.txDatas, v.liqDataTokens, v.liqDataAmounts, v.liqDataNativeAmounts, v.permit2datas);
    }

    /// @inheritdoc IPayloadHelper
    function decodeSrcPayload(uint256 srcPayloadId_)
        external
        view
        override
        returns (uint8 txType, uint8 callbackType, uint8 multi, address srcSender, uint64 srcChainId)
    {
        uint256 txInfo = srcPayloadRegistry.txHistory(srcPayloadId_);

        if (txInfo != 0) {
            (txType, callbackType, multi,, srcSender, srcChainId) = txInfo.decodeTxInfo();
        }
    }

    /// @inheritdoc IPayloadHelper
    function decodeTimeLockPayload(uint256 timelockPayloadId_)
        external
        view
        override
        returns (address srcSender, uint64 srcChainId, uint256 srcPayloadId, uint256 superformId, uint256 amount)
    {
        TwoStepsPayload memory payload = twoStepRegistry.getTwoStepsPayload(timelockPayloadId_);

        return (
            payload.srcSender, payload.srcChainId, payload.data.payloadId, payload.data.superformId, payload.data.amount
        );
    }

    function decodeTimeLockFailedPayload(uint256 timelockPayloadId_)
        external
        view
        override
        returns (address srcSender, uint64 srcChainId, uint256 srcPayloadId, uint256 superformId, uint256 amount)
    {
        IBaseStateRegistry timelockPayloadRegistry = IBaseStateRegistry(address(twoStepRegistry));
        bytes memory payloadBody = timelockPayloadRegistry.payloadBody(timelockPayloadId_);
        uint256 payloadHeader = timelockPayloadRegistry.payloadHeader(timelockPayloadId_);

        (, uint8 callbackType_,,, address srcSender_, uint64 srcChainId_) = payloadHeader.decodeTxInfo();

        /// @dev callback type can never be INIT / RETURN
        if (callbackType_ == uint256(CallbackType.FAIL)) {
            ReturnSingleData memory rsd = abi.decode(payloadBody, (ReturnSingleData));
            amount = rsd.amount;
            superformId = rsd.superformId;
            srcPayloadId = rsd.payloadId;
        }

        srcSender = srcSender_;
        srcChainId = srcChainId_;
    }
}
