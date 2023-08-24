// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import "forge-std/console.sol";

import "wormhole-solidity-sdk/interfaces/IWormhole.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";

import { IBaseStateRegistry } from "../../../interfaces/IBaseStateRegistry.sol";
import { IAmbImplementation } from "../../../interfaces/IAmbImplementation.sol";
import { ISuperRBAC } from "../../../interfaces/ISuperRBAC.sol";
import { ISuperRegistry } from "../../../interfaces/ISuperRegistry.sol";
import { AMBMessage, BroadCastAMBExtraData } from "../../../types/DataTypes.sol";
import { Error } from "../../../utils/Error.sol";
import { DataLib } from "../../../libraries/DataLib.sol";

/// @title WormholeImplementation
/// @author Zeropoint Labs
/// @notice allows state registries to use wormhole for crosschain communication
/// @dev uses automatic relayers of wormhole for 1:1 messaging
/// @dev uses multicast of wormhole for broadcasting
contract WormholeImplementation is IAmbImplementation, IWormholeReceiver {
    using DataLib for uint256;

    /*///////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ISuperRegistry public immutable superRegistry;
    IWormholeRelayer public immutable relayer;
    IWormhole public immutable wormhole;

    uint8 public broadcastFinality;

    mapping(uint64 => uint16) public ambChainId;
    mapping(uint16 => uint64) public superChainId;
    mapping(uint16 => address) public authorizedImpl;
    mapping(bytes32 => bool) public processedMessages;

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyProtocolAdmin() {
        if (!ISuperRBAC(superRegistry.getAddress(keccak256("SUPER_RBAC"))).hasProtocolAdminRole(msg.sender)) {
            revert Error.NOT_PROTOCOL_ADMIN();
        }
        _;
    }

    /*///////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param wormhole_ is wormhole address for respective chain
    /// @param relayer_ is the automatic relayer address for respective chain
    constructor(address wormhole_, address relayer_, ISuperRegistry superRegistry_) {
        relayer = IWormholeRelayer(relayer_);
        wormhole = IWormhole(wormhole_);
        superRegistry = superRegistry_;
    }

    /*///////////////////////////////////////////////////////////////
                                EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAmbImplementation
    function dispatchPayload(
        address srcSender_,
        uint64 dstChainId_,
        bytes memory message_,
        bytes memory extraData_
    )
        external
        payable
        virtual
        override
    {
        if (!superRegistry.isValidStateRegistry(msg.sender)) {
            revert Error.NOT_STATE_REGISTRY();
        }

        uint16 dstChainId = ambChainId[dstChainId_];

        (uint256 dstNativeAirdrop, uint256 dstGasLimit) = abi.decode(extraData_, (uint256, uint256));

        relayer.sendPayloadToEvm{ value: msg.value }(
            dstChainId, authorizedImpl[dstChainId], message_, dstNativeAirdrop, dstGasLimit
        );
    }

    /// @inheritdoc IAmbImplementation
    function broadcastPayload(
        address srcSender_,
        bytes memory message_,
        bytes memory extraData_
    )
        external
        payable
        virtual
    {
        /// @dev is wormhole's inherent fee for sending a message
        /// NOTE: is zero for now
        uint256 msgFee = wormhole.messageFee();

        if (msg.value != msgFee) {
            revert Error.CROSS_CHAIN_TX_UNDERPAID();
        }

        wormhole.publishMessage{ value: msg.value }(
            0,
            /// batch id
            message_,
            broadcastFinality
        );
    }

    /// @inheritdoc IWormholeReceiver
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    )
        public
        payable
        override
    {
        /// @dev 1. validate caller
        /// @dev 2. validate src chain sender
        /// @dev 3. validate message uniqueness
        if (msg.sender != address(relayer)) {
            revert Error.CALLER_NOT_RELAYER();
        }

        console.log(authorizedImpl[sourceChain]);
        console.log(_bytes32ToAddress(sourceAddress));
        if (_bytes32ToAddress(sourceAddress) != authorizedImpl[sourceChain]) {
            revert Error.INVALID_SRC_SENDER();
        }

        if (processedMessages[deliveryHash]) {
            revert Error.DUPLICATE_PAYLOAD();
        }

        processedMessages[deliveryHash] = true;

        /// @dev decoding payload
        AMBMessage memory decoded = abi.decode(payload, (AMBMessage));
        (,,, uint8 registryId,,) = decoded.txInfo.decodeTxInfo();
        address registryAddress = superRegistry.getStateRegistry(registryId);
        IBaseStateRegistry targetRegistry = IBaseStateRegistry(registryAddress);

        targetRegistry.receivePayload(superChainId[sourceChain], payload);
    }

    /// @dev allows protocol admin to add new chain ids in future
    /// @param superChainId_ is the identifier of the chain within superform protocol
    /// @param ambChainId_ is the identifier of the chain given by the AMB
    /// NOTE: cannot be defined in an interface as types vary for each message bridge (amb)
    function setChainId(uint64 superChainId_, uint16 ambChainId_) external onlyProtocolAdmin {
        if (superChainId_ == 0 || ambChainId_ == 0) {
            revert Error.INVALID_CHAIN_ID();
        }

        ambChainId[superChainId_] = ambChainId_;
        superChainId[ambChainId_] = superChainId_;

        emit ChainAdded(superChainId_);
    }

    /// @dev allows protocol admin to set receiver implmentation on a new chain id
    /// @param chainId_ is the identifier of the destination chain within wormhole
    /// @param authorizedImpl_ is the implementation of the wormhole message bridge on the specified destination
    /// NOTE: cannot be defined in an interface as types vary for each message bridge (amb)
    function setReceiver(uint16 chainId_, address authorizedImpl_) external onlyProtocolAdmin {
        if (chainId_ == 0) {
            revert Error.INVALID_CHAIN_ID();
        }

        if (authorizedImpl_ == address(0)) {
            revert Error.ZERO_ADDRESS();
        }

        authorizedImpl[chainId_] = authorizedImpl_;
        emit AuthorizedImplAdded(chainId_, authorizedImpl_);
    }

    /// @dev allows protocol admin to set broadcast finality
    /// @param finality_ is the required finality on src chain
    function setFinality(uint8 finality_) external onlyProtocolAdmin {
        if (finality_ == 0) {
            revert Error.INVALID_BROADCAST_FINALITY();
        }

        broadcastFinality = finality_;
    }

    /*///////////////////////////////////////////////////////////////
                    View Functions
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAmbImplementation
    function estimateFees(
        uint64 dstChainId_,
        bytes memory,
        bytes memory extraData_
    )
        external
        view
        override
        returns (uint256 fees)
    {
        uint256 dstNativeAirdrop;
        uint256 dstGasLimit;

        if (extraData_.length > 0) {
            (dstNativeAirdrop, dstGasLimit) = abi.decode(extraData_, (uint256, uint256));
        }

        uint16 dstChainId = ambChainId[dstChainId_];

        if (dstChainId != 0) {
            (fees,) = relayer.quoteEVMDeliveryPrice(dstChainId, dstNativeAirdrop, dstGasLimit);
        }
    }

    /*///////////////////////////////////////////////////////////////
                    INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev casts a bytes32 string to address
    /// @param buf_ is the bytes32 string to be casted
    /// @return a address variable of the address passed in params
    function _bytes32ToAddress(bytes32 buf_) internal pure returns (address) {
        return address(uint160(uint256(buf_)));
    }
}
