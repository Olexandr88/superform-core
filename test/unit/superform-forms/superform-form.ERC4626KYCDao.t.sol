// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import { Error } from "src/libraries/Error.sol";
import { SuperformFactory, ISuperformFactory } from "src/SuperformFactory.sol";

import "test/utils/ProtocolActions.sol";

contract SuperformERC4626KYCDaoFormTest is BaseSetup {
    uint64 internal chainId = ETH;
    address receiverAddress = address(444);

    function setUp() public override {
        super.setUp();
    }

    /// @dev Test caller auth
    function test_kycDaoOnlyProtocolAdmin() public {
        vm.selectFork(FORKS[ETH]);

        address superform = getContract(
            ETH, string.concat("DAI", "kycDAO4626", "Superform", Strings.toString(FORM_IMPLEMENTATION_IDS[2]))
        );

        vm.expectRevert(Error.NOT_PROTOCOL_ADMIN.selector);
        ERC4626KYCDaoForm(superform).mintKYC(uint32(8));
    }

    /// @dev Test Vault Symbol
    function test_superformRevertKYCDaoCheck() public {
        /// scenario: user deposits with his own token and has approved enough tokens
        vm.selectFork(FORKS[ETH]);
        vm.startPrank(deployer);

        address superform = getContract(
            ETH, string.concat("DAI", "kycDAO4626", "Superform", Strings.toString(FORM_IMPLEMENTATION_IDS[2]))
        );

        uint256 superformId = DataLib.packSuperform(superform, FORM_IMPLEMENTATION_IDS[2], ETH);

        SingleVaultSFData memory data = SingleVaultSFData(
            superformId,
            1e18,
            1e18,
            100,
            LiqRequest("", getContract(ETH, "DAI"), address(0), 1, ETH, 0),
            "",
            false,
            false,
            receiverAddress,
            receiverAddress,
            ""
        );

        SingleDirectSingleVaultStateReq memory req = SingleDirectSingleVaultStateReq(data);

        address router = getContract(ETH, "SuperformRouter");

        /// @dev approves before call
        MockERC20(getContract(ETH, "DAI")).approve(router, 1e18);
        vm.expectRevert(Error.NO_VALID_KYC_TOKEN.selector);
        SuperformRouter(payable(getContract(ETH, "SuperformRouter"))).singleDirectSingleVaultDeposit(req);

        vm.stopPrank();
    }

    function test_superformXChainKycDAOWithdrawalWithoutUpdatingTxData() public {
        /// @dev prank deposits (just mint super-shares)
        vm.selectFork(FORKS[ETH]);
        vm.startPrank(deployer);

        address superform = getContract(
            ETH, string.concat("DAI", "kycDAO4626", "Superform", Strings.toString(FORM_IMPLEMENTATION_IDS[2]))
        );

        uint256 superformId = DataLib.packSuperform(superform, FORM_IMPLEMENTATION_IDS[2], ETH);

        MockERC20(getContract(ETH, "DAI")).transfer(superform, 1e18);
        vm.stopPrank();

        InitSingleVaultData memory data = InitSingleVaultData(
            1,
            superformId,
            1e18,
            1e18,
            100,
            LiqRequest(bytes(""), getContract(ETH, "DAI"), address(0), 1, ARBI, 0),
            false,
            false,
            receiverAddress,
            ""
        );

        /// @dev simulating withdrawals with malicious tx data
        vm.prank(getContract(ETH, "CoreStateRegistry"));
        vm.expectRevert(Error.NOT_IMPLEMENTED.selector);
        IBaseForm(superform).xChainDepositIntoVault(data, deployer, ARBI);

        /// @dev simulating withdrawals with malicious tx data
        vm.prank(getContract(ETH, "CoreStateRegistry"));
        vm.expectRevert(Error.NOT_IMPLEMENTED.selector);
        IBaseForm(superform).xChainWithdrawFromVault(data, deployer, ARBI);
    }

    function test_superform_invalidChainId() public {
        /// @dev prank deposits (just mint super-shares)
        vm.selectFork(FORKS[ETH]);
        vm.startPrank(deployer);

        address superform = getContract(
            ETH, string.concat("DAI", "kycDAO4626", "Superform", Strings.toString(FORM_IMPLEMENTATION_IDS[2]))
        );

        uint256 superformId = DataLib.packSuperform(superform, FORM_IMPLEMENTATION_IDS[2], ETH);

        MockERC20(getContract(ETH, "DAI")).transfer(superform, 1e18);
        vm.stopPrank();

        InitSingleVaultData memory data = InitSingleVaultData(
            1,
            superformId,
            1e18,
            1e18,
            100,
            LiqRequest(bytes(""), getContract(ETH, "DAI"), address(0), 1, ARBI, 0),
            false,
            false,
            receiverAddress,
            ""
        );

        vm.prank(getContract(ETH, "CoreStateRegistry"));
        vm.expectRevert(Error.INVALID_CHAIN_ID.selector);
        IBaseForm(superform).xChainWithdrawFromVault(data, deployer, 0);

        vm.prank(getContract(ETH, "CoreStateRegistry"));
        vm.expectRevert(Error.INVALID_CHAIN_ID.selector);
        IBaseForm(superform).xChainDepositIntoVault(data, deployer, 0);
    }

    function test_forwardDustToPaymaster() public {
        /// @dev prank deposits (just mint super-shares)
        vm.selectFork(FORKS[ETH]);
        vm.prank(deployer);

        address superform = getContract(
            ETH, string.concat("DAI", "kycDAO4626", "Superform", Strings.toString(FORM_IMPLEMENTATION_IDS[2]))
        );

        IBaseForm(superform).forwardDustToPaymaster(getContract(ETH, "DAI"));
    }

    function test_emergencyWithdraw() public {
        /// @dev prank deposits (just mint super-shares)
        vm.selectFork(FORKS[ETH]);
        vm.prank(deployer);

        address superform = getContract(
            ETH, string.concat("DAI", "kycDAO4626", "Superform", Strings.toString(FORM_IMPLEMENTATION_IDS[2]))
        );
        deal(IBaseForm(superform).getVaultAddress(), superform, 1e18);

        vm.prank(getContract(ETH, "EmergencyQueue"));

        IBaseForm(superform).emergencyWithdraw(receiverAddress, 1e18);
    }

    function test_directDepositIntoVault_SuperformIdNonexistent_timelock() public {
        vm.selectFork(FORKS[ETH]);

        address superform = getContract(
            ETH, string.concat("DAI", "kycDAO4626", "Superform", Strings.toString(FORM_IMPLEMENTATION_IDS[2]))
        );

        uint256 nonexistentSuperformId = 123;
        InitSingleVaultData memory data = InitSingleVaultData(
            0,
            nonexistentSuperformId,
            0,
            0,
            0,
            LiqRequest(bytes(""), address(0), address(0), 0, 0, 0),
            false,
            false,
            address(0),
            ""
        );

        vm.prank(getContract(ETH, "SuperformRouter"));
        vm.expectRevert(Error.SUPERFORM_ID_NONEXISTENT.selector);
        ERC4626KYCDaoForm(payable(superform)).directDepositIntoVault(data, address(0));
    }

    function test_directDepositIntoVault_Paused_kycdao() public {
        vm.selectFork(FORKS[ETH]);

        address superform = getContract(
            ETH, string.concat("DAI", "kycDAO4626", "Superform", Strings.toString(FORM_IMPLEMENTATION_IDS[2]))
        );
        uint256 superformId = DataLib.packSuperform(superform, FORM_IMPLEMENTATION_IDS[2], ETH);
        InitSingleVaultData memory data = InitSingleVaultData(
            0,
            superformId,
            0,
            0,
            0,
            LiqRequest(bytes(""), address(0), address(0), 0, 0, 0),
            false,
            false,
            address(0),
            ""
        );

        vm.prank(deployer);
        SuperformFactory(getContract(ETH, "SuperformFactory")).changeFormImplementationPauseStatus(
            FORM_IMPLEMENTATION_IDS[2], ISuperformFactory.PauseStatus.PAUSED, bytes("")
        );

        vm.prank(getContract(ETH, "SuperformRouter"));
        vm.expectRevert(Error.PAUSED.selector);
        ERC4626Form(payable(superform)).directDepositIntoVault(data, address(0));
    }
}
