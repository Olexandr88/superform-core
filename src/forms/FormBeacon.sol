// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IFormBeacon} from "../interfaces/IFormBeacon.sol";
import {ISuperRegistry} from "../interfaces/ISuperRegistry.sol";
import {ISuperRBAC} from "../interfaces/ISuperRBAC.sol";
import {Error} from "../utils/Error.sol";

/// @title FormBeacon
/// @notice The Beacon for any given form.
contract FormBeacon is IFormBeacon {
    /*///////////////////////////////////////////////////////////////
                    State Variables
    //////////////////////////////////////////////////////////////*/

    ISuperRegistry public immutable superRegistry;

    UpgradeableBeacon immutable beacon;

    /// @notice chainId represents unique chain id for each chains.
    uint16 public immutable chainId;

    address public formLogic;

    bool public paused;

    modifier onlySuperFormFactory() {
        if (
            !ISuperRBAC(superRegistry.superRBAC()).hasSuperformFactoryRole(
                msg.sender
            )
        ) revert Error.NOT_SUPERFORM_FACTORY();
        _;
    }

    /// @param chainId_              SuperForm chain id
    /// @param superRegistry_        SuperForm registry contract
    /// @param formLogic_            The initial form logic contract
    constructor(uint16 chainId_, address superRegistry_, address formLogic_) {
        chainId = chainId_;
        superRegistry = ISuperRegistry(superRegistry_);
        beacon = new UpgradeableBeacon(formLogic_);
        formLogic = formLogic_;
    }

    /// @inheritdoc IFormBeacon
    function update(address formLogic_) external override onlySuperFormFactory {
        beacon.upgradeTo(formLogic_);
        address oldLogic = formLogic;
        formLogic = formLogic_;

        emit FormLogicUpdated(oldLogic, formLogic_);
    }

    /// @inheritdoc IFormBeacon
    function changePauseStatus(
        bool newStatus_
    ) external override onlySuperFormFactory {
        paused = newStatus_;
        emit FormBeaconStatus(newStatus_);
    }

    /// @inheritdoc IFormBeacon
    function implementation() external view override returns (address) {
        return beacon.implementation();
    }
}
