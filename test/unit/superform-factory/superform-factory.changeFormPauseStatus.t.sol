// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import { SuperformFactory } from "src/SuperformFactory.sol";
import { ERC4626Form } from "src/forms/ERC4626Form.sol";
import "test/utils/BaseSetup.sol";
import { Error } from "src/libraries/Error.sol";

contract SuperformFactoryChangePauseTest is BaseSetup {
    uint64 internal chainId = ETH;

    event FormLogicUpdated(address indexed oldLogic, address indexed newLogic);

    function setUp() public override {
        super.setUp();
    }

    function test_addFormImplementation_NOT_PROTOCOL_ADMIN() public {
        vm.selectFork(FORKS[chainId]);

        address superRegistry = getContract(chainId, "SuperRegistry");

        /// @dev Deploying Forms
        address formImplementation1 = address(new ERC4626Form(superRegistry));
        uint32 formImplementationId = 0;

        vm.prank(address(0x2828));
        vm.expectRevert(Error.NOT_PROTOCOL_ADMIN.selector);
        SuperformFactory(getContract(chainId, "SuperformFactory")).addFormImplementation(
            formImplementation1, formImplementationId, 1
        );
    }

    function test_changeFormImplementationPauseStatus_NOT_EMERGENCY_ADMIN() public {
        vm.selectFork(FORKS[chainId]);
        uint32 formImplementationId = 0;

        vm.prank(address(0x2828));
        vm.expectRevert(Error.NOT_EMERGENCY_ADMIN.selector);
        SuperformFactory(getContract(chainId, "SuperformFactory")).changeFormImplementationPauseStatus(
            formImplementationId, ISuperformFactory.PauseStatus.PAUSED, generateBroadcastParams(0)
        );
    }

    function test_changeFormImplementationPauseStatus() public {
        vm.startPrank(deployer);

        vm.selectFork(FORKS[chainId]);

        address superRegistry = getContract(chainId, "SuperRegistry");

        /// @dev Deploying Forms
        address formImplementation1 = address(new ERC4626Form(superRegistry));
        uint32 formImplementationId = 0;

        // Deploying Forms Using AddImplementation. Not Testing Reverts As Already Tested
        SuperformFactory(getContract(chainId, "SuperformFactory")).addFormImplementation(
            formImplementation1, formImplementationId, 1
        );

        SuperformFactory(getContract(chainId, "SuperformFactory")).changeFormImplementationPauseStatus(
            formImplementationId, ISuperformFactory.PauseStatus.PAUSED, generateBroadcastParams(0)
        );

        bool status = SuperformFactory(payable(getContract(chainId, "SuperformFactory"))).isFormImplementationPaused(
            formImplementationId
        );

        assertEq(status, true);
    }

    function test_changeFormImplementationPauseStatusNoBroadcast() public {
        vm.startPrank(deployer);

        vm.selectFork(FORKS[chainId]);

        address superRegistry = getContract(chainId, "SuperRegistry");

        /// @dev Deploying Forms
        address formImplementation1 = address(new ERC4626Form(superRegistry));
        uint32 formImplementationId = 0;

        // Deploying Forms Using AddImplementation. Not Testing Reverts As Already Tested
        SuperformFactory(getContract(chainId, "SuperformFactory")).addFormImplementation(
            formImplementation1, formImplementationId, 1
        );

        SuperformFactory(getContract(chainId, "SuperformFactory")).changeFormImplementationPauseStatus(
            formImplementationId, ISuperformFactory.PauseStatus.PAUSED, ""
        );

        bool status = SuperformFactory(payable(getContract(chainId, "SuperformFactory"))).isFormImplementationPaused(
            formImplementationId
        );

        assertEq(status, true);
    }

    function test_changeFormImplementationPauseStatusNoBroadcastRevertCase() public {
        vm.startPrank(deployer);

        vm.selectFork(FORKS[chainId]);

        address superRegistry = getContract(chainId, "SuperRegistry");

        /// @dev Deploying Forms
        address formImplementation1 = address(new ERC4626Form(superRegistry));
        uint32 formImplementationId = 0;

        // Deploying Forms Using AddImplementation. Not Testing Reverts As Already Tested
        SuperformFactory(getContract(chainId, "SuperformFactory")).addFormImplementation(
            formImplementation1, formImplementationId, 1
        );

        vm.expectRevert(Error.MSG_VALUE_NOT_ZERO.selector);
        SuperformFactory(getContract(chainId, "SuperformFactory")).changeFormImplementationPauseStatus{ value: 1 ether }(
            formImplementationId, ISuperformFactory.PauseStatus.PAUSED, ""
        );
    }

    function test_revert_changeFormImplementationPauseStatus_INVALID_FORM_ID() public {
        vm.startPrank(deployer);

        vm.selectFork(FORKS[chainId]);

        address superRegistry = getContract(chainId, "SuperRegistry");

        /// @dev Deploying Forms
        address formImplementation1 = address(new ERC4626Form(superRegistry));
        uint32 formImplementationId = 0;
        uint32 formImplementationId_invalid = 999;

        /// @dev Deploying Forms Using AddImplementation. Not Testing Reverts As Already Tested
        SuperformFactory(getContract(chainId, "SuperformFactory")).addFormImplementation(
            formImplementation1, formImplementationId, 1
        );

        /// @dev Invalid Form Implementation For Pausing
        vm.expectRevert(Error.INVALID_FORM_ID.selector);
        SuperformFactory(getContract(chainId, "SuperformFactory")).changeFormImplementationPauseStatus{
            value: 800 * 10 ** 18
        }(formImplementationId_invalid, ISuperformFactory.PauseStatus.PAUSED, generateBroadcastParams(0));
    }

    function test_changeFormImplementationPauseZeroMsgValueNotSent() public {
        vm.startPrank(deployer);

        vm.selectFork(FORKS[chainId]);

        address superRegistry = getContract(chainId, "SuperRegistry");

        /// @dev Deploying Forms
        address formImplementation1 = address(new ERC4626Form(superRegistry));
        uint32 formImplementationId = 0;

        // Deploying Forms Using AddImplementation. Not Testing Reverts As Already Tested
        SuperformFactory(getContract(chainId, "SuperformFactory")).addFormImplementation(
            formImplementation1, formImplementationId, 1
        );

        vm.expectRevert(Error.MSG_VALUE_NOT_ZERO.selector);
        SuperformFactory(getContract(chainId, "SuperformFactory")).changeFormImplementationPauseStatus{
            value: 800 * 10 ** 18
        }(formImplementationId, ISuperformFactory.PauseStatus.PAUSED, "");
    }
}
