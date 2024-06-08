// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakeContract{
   IERC20 public stakingToken;

   uint public constant DURATION = 180 days;
   uint public constant BASE_APR = 200;
   uint public constant FLAT_APR = 20;
   uint256 public constant TVL = 100000000;

  mapping(address => bool) public isAdmin;
  uint256 public totalStaked;
  uint256 public rewardRate;

  event Staked(address indexed user, uint256 amount);
  event UnStaked(address indexed user, uint256 amount);
  event RewardRateUpdated(uint rewardRate);
  event Claimed(address user, uint256 rewards);

  event Reward(uint256 user_amount, uint256 user_reward, uint pending);

    struct TokenStake{
       uint256 amount;
       uint256 reward;
       uint256 lastclaimed; 
       
    }
    constructor(IERC20 stakingInit) {
        stakingToken = stakingInit;
        isAdmin[address(this)] = true;
        updateRewardRate();
    }

    mapping(address => TokenStake) public stakings;

    function stake(uint256 amount) public payable {
        require(amount>0, "Cannot be Zero");
        address owner = msg.sender;
        TokenStake memory userStake = stakings[owner];
        userStake = updateReward(userStake);
        stakingToken.transferFrom(msg.sender, address(this),amount);
        userStake.amount = userStake.amount + amount;
        totalStaked = totalStaked + amount;
        userStake.lastclaimed = block.timestamp;

        stakings[owner] = userStake;
        updateRewardRate();
        emit Staked(owner, amount);

    }

    function unstake(uint256 amount) external payable  {
        address owner = msg.sender;
        TokenStake memory userStake = stakings[owner];
        require(userStake.amount >= amount, "Exceeds staked amount");

        updateReward(userStake);
        userStake.amount -= amount;
        totalStaked -= amount;
        stakingToken.transfer(msg.sender, amount);
        stakings[owner] = userStake;
        updateRewardRate();
        emit UnStaked(msg.sender, amount);
    }

    function updateReward(TokenStake memory userStake) public returns (TokenStake memory re){

        if (userStake.amount > 0) {
            uint256 pendingReward = ((userStake.amount / stakingToken.balanceOf(address(this)))* rewardRate * ((block.timestamp - userStake.lastclaimed)/5));

            userStake.reward = userStake.reward  + pendingReward;
            userStake.lastclaimed = block.timestamp;
            emit Reward(userStake.amount, userStake.reward , userStake.lastclaimed);
            return userStake;
            
        }
    }

    function updateRewardRate() public {
        if (totalStaked >= TVL) {
            rewardRate = ((stakingToken.balanceOf(address(this)) * FLAT_APR) / 100) / (365 days);
        } else {
            rewardRate = ((stakingToken.balanceOf(address(this)) * BASE_APR) / 100) / (365 days); // each 5 second 
        }

        emit RewardRateUpdated(rewardRate);
    }

    function claimRewards() external {
        address owner = msg.sender;
        TokenStake memory userStake = stakings[owner];
        userStake = updateReward(userStake);

        uint256 rewards = userStake.reward;
        userStake.reward = 0;

        if (rewards > 0) {
            stakingToken.transfer(msg.sender, rewards);
            stakings[owner] = userStake;
            emit Claimed(msg.sender, rewards);
        }
    }

    function claimTokensForUser(address user) external onlyAdmin{
        address owner = msg.sender;
        TokenStake memory userStake = stakings[owner];
        userStake = updateReward(userStake);

        uint256 rewards = userStake.reward;
        userStake.reward = 0;

        if (rewards > 0) {
            stakingToken.transfer(user, rewards);
            stakings[owner] = userStake;
            emit Claimed(user, rewards);
        }
    }

    modifier onlyAdmin() {
      require(isAdmin[msg.sender], "Not authorized");
      _;
    }

    function QueryRewards() public view returns (uint256) {
      address account = msg.sender;
       TokenStake memory userStake = stakings[account];
        uint256 pendingReward = ((userStake.amount / stakingToken.balanceOf(address(this)))* rewardRate * ((block.timestamp - userStake.lastclaimed)/5));
        return userStake.reward + pendingReward;
    }

    function QueryUserDetails() public view returns (TokenStake memory){
      address owner = msg.sender;
      return stakings[owner];
    }
}
