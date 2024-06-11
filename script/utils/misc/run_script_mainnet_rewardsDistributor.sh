#!/usr/bin/env bash
# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export ETHEREUM_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential)
export BSC_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSC_RPC_URL/credential)
export AVALANCHE_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/AVALANCHE_RPC_URL/credential)
export POLYGON_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/POLYGON_RPC_URL/credential)
export ARBITRUM_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBITRUM_RPC_URL/credential)
export OPTIMISM_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/OPTIMISM_RPC_URL/credential)
export BASE_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)
export FANTOM_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/FANTOM_RPC_URL/credential)
export FIREBLOCKS_API_KEY=$(op read op://zry2qwhqux2w6qtjitg44xb7b4/FB_STAGING_TOOLBOX_ACTION/credential)
export FIREBLOCKS_API_PRIVATE_KEY_PATH=$(op read op://zry2qwhqux2w6qtjitg44xb7b4/FB_STAGING_TOOLBOX_SECRET_SSH/private_key)
export FOUNDRY_PROFILE=production

# Run the script
# echo Deploying RewardsDistributor: ...

# FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "deployRewardsDistributor(uint256,uint256,uint256)" 0 0 0 --rpc-url $ETHEREUM_RPC_URL --slow --account defaultKey --sender 0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92 --legacy

# wait

# FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "deployRewardsDistributor(uint256,uint256,uint256)" 0 1 0 --rpc-url $BSC_RPC_URL --slow --account defaultKey --sender 0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92

# wait

# FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "deployRewardsDistributor(uint256,uint256,uint256)" 0 2 0 --rpc-url $AVALANCHE_RPC_URL --slow --account defaultKey --sender 0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92

# wait

# FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "deployRewardsDistributor(uint256,uint256,uint256)" 0 3 0 --rpc-url $POLYGON_RPC_URL --slow --account defaultKey --sender 0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92

# wait

# FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "deployRewardsDistributor(uint256,uint256,uint256)" 0 4 0 --rpc-url $ARBITRUM_RPC_URL --slow --account defaultKey --sender 0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92 --legacy

# wait

# FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "deployRewardsDistributor(uint256,uint256,uint256)" 0 5 0 --rpc-url $OPTIMISM_RPC_URL --slow --account defaultKey --sender 0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92 --legacy

# wait

# FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "deployRewardsDistributor(uint256,uint256,uint256)" 0 6 0 --rpc-url $BASE_RPC_URL --slow --account defaultKey --sender 0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92 --legacy

# wait

# FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "deployRewardsDistributor(uint256,uint256,uint256)" 0 7 1 --rpc-url $FANTOM_RPC_URL --slow --account defaultKey --sender 0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92 --legacy

# wait 

echo Configuring RewardsDistributor To SuperRegistry: ...

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "configureSettings(uint256,uint256)" 0 0 --rpc-url $ETHEREUM_RPC_URL --broadcast --slow --sender 0x1985df46791BEBb1e3ed9Ec60417F38CECc1D349

wait

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "configureSettings(uint256,uint256)" 0 1 --rpc-url $BSC_RPC_URL --broadcast --slow --sender 0x1985df46791BEBb1e3ed9Ec60417F38CECc1D349

wait

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "configureSettings(uint256,uint256)" 0 2 --rpc-url $AVALANCHE_RPC_URL --broadcast --slow --sender 0x1985df46791BEBb1e3ed9Ec60417F38CECc1D349

wait

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "configureSettings(uint256,uint256)" 0 3 --rpc-url $POLYGON_RPC_URL --broadcast --slow --sender 0x1985df46791BEBb1e3ed9Ec60417F38CECc1D349

wait

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "configureSettings(uint256,uint256)" 0 4 --rpc-url $ARBITRUM_RPC_URL --broadcast --slow --sender 0x1985df46791BEBb1e3ed9Ec60417F38CECc1D349

wait

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "configureSettings(uint256,uint256)" 0 5 --rpc-url $OPTIMISM_RPC_URL --broadcast --slow --sender 0x1985df46791BEBb1e3ed9Ec60417F38CECc1D349 --legacy

wait

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "configureSettings(uint256,uint256)" 0 6 --rpc-url $BASE_RPC_URL --broadcast --slow --sender 0x1985df46791BEBb1e3ed9Ec60417F38CECc1D349 --legacy

wait

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.Deploy.RewardsDistributor.s.sol:MainnetDeployRewardsDistributor --sig "configureSettings(uint256,uint256)" 0 7 --rpc-url $FANTOM_RPC_URL --broadcast --slow --sender 0x1985df46791BEBb1e3ed9Ec60417F38CECc1D349

wait
