// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./ERC20.sol";
import "./StakingPool.sol";
contract IDOPool is Ownable, ReentrancyGuard{

	using SafeMath for uint256;	

	uint256 public tokenPrice;
    ERC20 public rewardToken;
    uint256 public decimals;
    uint256 public round1startTimestamp;
    uint256 public round1endTimestamp;
    uint256 public round2startTimestamp;
    uint256 public round2endTimestamp;
    uint256 public round3startTimestamp;
    uint256 public round3endTimestamp;    
    uint256 public startClaimTimestamp;
    uint256 public totalSupply;
    uint256 public fundingGoal;    
    
    uint public supplyRound1;
    uint public supplyRound2;
    uint public supplyRound3;

    uint public shareRound1;
    uint public shareRound2;
    uint public shareRound3;

    uint public distributionRound1;
    uint public distributionRound2;
    uint public distributionRound3;

    uint public gigaPoolWeight;
		uint public megaPoolWeight;
		uint public microPoolWeight;
		uint public nanoPoolWeight;	

    StakingPool public stakingPool;
    
    address[] public investorRound1;
    address[] public investorRound2;
    address[] public investorRound3;

    address[] public investorRound1Pool1;
    address[] public investorRound1Pool2;
    address[] public investorRound1Pool3;
    address[] public investorRound1Pool4;
    
    mapping(address => InvestorInfo) public investorEligibleRound1;
    mapping(address => InvestorInfo) public investorEligibleRound2;
    mapping(address => InvestorInfo) public investorEligibleRound3;    

    //hasEligibleRound is true if User is already added to the list
		mapping(address => bool) public hasEligibleRound1;
		mapping(address => bool) public hasEligibleRound2;
		mapping(address => bool) public hasEligibleRound3;

		ERC20 public usdc;

	struct InvestorInfo{						
		uint eligibleToken;
		uint purchasedToken;
		uint eligibleUSDC;
		uint depositedUSDC;
		uint poolWeight;	
		uint extraUSDCPurchased;	
	}		

	event TokensPurchased(
        address indexed holder,
        uint256 amount,
        uint256 tokenAmount
    );
    
  event TokensWithdrawn(address indexed holder, uint256 amount);

	event USDCRefunded(
				address indexed holder,
        uint256 amount,
        uint256 tokenAmount
    );


	constructor(
        uint256 _tokenPrice,
        ERC20 _rewardToken,
        uint256 _round1startTimestamp,
        uint256 _round1endTimestamp,
        uint256 _round2startTimestamp,
        uint256 _round2endTimestamp,
        uint256 _round3startTimestamp,
        uint256 _round3endTimestamp,
        uint256 _startClaimTimestamp,
        uint256 _totalSupply,
        uint256 _fundingGoal     
    ) {
        tokenPrice = _tokenPrice;
        rewardToken = _rewardToken;
        decimals = rewardToken.decimals();        
        round1startTimestamp = _round1startTimestamp;
        round1endTimestamp = _round1endTimestamp;
        round2startTimestamp = _round2startTimestamp;
        round2endTimestamp = _round2endTimestamp;
        round3startTimestamp = _round3startTimestamp;
        round3endTimestamp = _round3endTimestamp;        
        startClaimTimestamp = _startClaimTimestamp;
        totalSupply = _totalSupply;
        fundingGoal = _fundingGoal;        
        nanoPoolWeight = 8;
        microPoolWeight = 14;
        megaPoolWeight = 29;
        gigaPoolWeight = 49;
        supplyRound1 = totalSupply.mul(60).div(100);
        supplyRound2 = totalSupply.mul(40).div(100);
        distributionRound1 = 0;
        distributionRound2 = 0;
        distributionRound3 = 0;
        usdc = ERC20(address(0xdAC17F958D2ee523a2206206994597C13D831ec7));
    }  


    function buyTokenRound1(uint _amount) payable external {
        require(block.timestamp >= round1startTimestamp, "Round 1 Not started");
        require(block.timestamp < round1endTimestamp, "Round 1 Ended");
				
				InvestorInfo storage investorInfo = investorEligibleRound1[msg.sender];
        
        require(investorInfo.eligibleUSDC >= _amount, "More then max amount");

        distributionRound1 = distributionRound1.add(_amount);
        
        usdc.transfer(address(this), _amount);
        investorInfo.depositedUSDC = _amount;
        
        emit TokensPurchased(msg.sender, _amount, convertUSDCToToken(_amount));
    }

    function buyTokenRound2(uint _amount) payable external {
        require(block.timestamp >= round2startTimestamp, "Round 2 Not started");
        require(block.timestamp < round2endTimestamp, "Round 2 Ended");
				
				InvestorInfo storage investorInfo = investorEligibleRound2[msg.sender];
        
        require(investorInfo.eligibleUSDC >= _amount, "More then max amount");

        distributionRound2 = distributionRound2.add(_amount);
        
        usdc.transfer(address(this), _amount);
        investorInfo.depositedUSDC = _amount;
        
        emit TokensPurchased(msg.sender, msg.value, convertUSDCToToken(_amount));
    }

    function buyTokenRound3(uint _amount) payable external {
        require(block.timestamp >= round3startTimestamp, "Round 3 Not started");
        require(block.timestamp < round3endTimestamp, "Round 3 Ended");
				
				InvestorInfo storage investorInfo = investorEligibleRound3[msg.sender];

        // require(distributionRound3.add(investorInfo.eligibleUSDC) <= fundingGoal, "Overfilled");
        require(investorInfo.eligibleUSDC >= _amount, "More then max amount");

        distributionRound3 = distributionRound3.add(_amount);
        
        usdc.transfer(address(this), _amount);
        investorInfo.depositedUSDC = _amount;
        
        emit TokensPurchased(msg.sender, msg.value, convertUSDCToToken(_amount));
    }

    //check if total distribution for round 1 exceeds supply
    function refundUSDCRound1() public onlyOwner{
    	require(convertTokenPriceToUSDC(supplyRound1) < distributionRound1, "Round 1 collection is lower than funding goal");

    	InvestorInfo storage investorInfo;

    	//return the extra % of total funds collected to each investor
    	uint extraUSDCPurchased = calculateExtraFundPercent();
    	for (uint256 s = 0; s <= investorRound1.length; s += 1){
    		investorInfo = investorEligibleRound1[investorRound1[s]];
    		investorInfo.extraUSDCPurchased = extraUSDCPurchased.mul(investorInfo.depositedUSDC);
    		usdc.transfer(investorRound1[s], investorInfo.extraUSDCPurchased);
    		emit USDCRefunded(investorRound1[s], investorInfo.extraUSDCPurchased, convertUSDCToToken(investorInfo.extraUSDCPurchased));
    	}
    }

    //check if total distribution for round 2 exceeds supply
    function refundUSDCRound2() public onlyOwner{
    	require(convertTokenPriceToUSDC(supplyRound2) < distributionRound2, "Round 2 collection is lower than funding goal");

    	InvestorInfo storage investorInfo;

    	//return the extra % of total funds collected to each investor
    	uint extraUSDCPurchased = calculateExtraFundPercent();
    	for (uint256 s = 0; s <= investorRound2.length; s += 1){
    		investorInfo = investorEligibleRound2[investorRound2[s]];
    		investorInfo.extraUSDCPurchased = extraUSDCPurchased.mul(investorInfo.depositedUSDC);
    		usdc.transfer(investorRound2[s], investorInfo.extraUSDCPurchased);
    		emit USDCRefunded(investorRound2[s], investorInfo.extraUSDCPurchased, convertUSDCToToken(investorInfo.extraUSDCPurchased));
    	}
    }

    //check if total distribution for round 3 exceeds supply
    function refundUSDCRound3() public onlyOwner{
    	require(convertTokenPriceToUSDC(supplyRound3) < distributionRound3, "Round 2 collection is lower than funding goal");

    	InvestorInfo storage investorInfo;

    	//return the extra % of total funds collected to each investor
    	uint extraUSDCPurchased = calculateExtraFundPercent();
    	for (uint256 s = 0; s <= investorRound3.length; s += 1){
    		investorInfo = investorEligibleRound3[investorRound3[s]];
    		investorInfo.extraUSDCPurchased = extraUSDCPurchased.mul(investorInfo.depositedUSDC);
    		usdc.transfer(investorRound3[s], investorInfo.extraUSDCPurchased);
    		emit USDCRefunded(investorRound3[s], investorInfo.extraUSDCPurchased, convertUSDCToToken(investorInfo.extraUSDCPurchased));
    	}
    }

    function calculateExtraFundPercent() internal view returns (uint){
    	return distributionRound1.sub(supplyRound1).div(supplyRound1);
    }

    // @dev Allows to claim tokens for the specific user.
    // @param _user Token receiver.
    function claimFor(address _user) external {
        proccessClaim(_user);
    }

    // @dev Allows to claim tokens for themselves.
    function claim() external {
        proccessClaim(msg.sender);
    }

    // @dev Proccess the claim.
    // @param _receiver Token receiver.
    function proccessClaim(address _receiver) internal nonReentrant{
        require(block.timestamp > startClaimTimestamp, "Distribution not started");
        InvestorInfo storage investorInfo;
        if(hasEligibleRound1[_receiver]){
        	investorInfo = investorEligibleRound1[_receiver];
        }else if(hasEligibleRound2[_receiver]){
        	investorInfo = investorEligibleRound2[_receiver];
        }else if(hasEligibleRound3[_receiver]){
        	investorInfo = investorEligibleRound3[_receiver];
        }        
        uint256 _amount = investorInfo.purchasedToken;
        if (_amount > 0) {                        
            rewardToken.transfer(_receiver, _amount);
            emit TokensWithdrawn(_receiver,_amount);
        }
    }

    function withdrawUSDC() external onlyOwner {
        // This forwards all available gas. Be sure to check the return value!
     		usdc.transfer(msg.sender, distributionRound1.add(distributionRound2).add(distributionRound3));        
    }

  /**
   * @dev add an address to the whitelist   
   */
  function addAddressToWhitelist(address _operator, uint round)
    public
    onlyOwner    
  {  
  //Add investors to the eligibleRound array if not added before  
    if(round == 1){
    	if(!hasEligibleRound1[_operator]){
    		investorRound1.push(_operator);
    		hasEligibleRound1[_operator] = true;    		
    	}
    }else if(round == 2){
    	if(!hasEligibleRound2[_operator]){
    		investorRound2.push(_operator);
    		hasEligibleRound2[_operator] = true;
    	}    	
    }else if(round == 3){
    	if(!hasEligibleRound3[_operator]){
			investorRound3.push(_operator);
			hasEligibleRound3[_operator] = true;
    	}    	
    }
  }

  /**
   * @dev add addresses to the whitelist   
   * false if all addresses were already in the whitelist
   */
  function addAddressesToWhitelist(address[] memory _operators, uint round)
    public
    onlyOwner
  {
    for (uint256 i = 0; i < _operators.length; i++) {
      addAddressToWhitelist(_operators[i], round);
    }
  }

  //divide investors into pools for round 1
  function allotInvestorsPoolsRound1() public{
  	//check staking of each investor & move to pool array
  	uint pool;  	  	
  	for (uint256 s = 0; s <= investorRound1.length; s += 1){
  		if(stakingPool.isStakeholder(investorRound1[s])){
  			pool = stakingPool.getStaker(investorRound1[s]);
  				moveInvestorToPool(investorRound1[s], pool);
  		}		
  	}

  	this.calculateTokenShareRound1();
  	this.allotTokenRound1();
  }

  function moveInvestorToPool(address _stakerAddress, uint pool) internal{  	
		if(pool == 4){			
			investorRound1Pool4.push(_stakerAddress);			
		}else if(pool == 3){			
			investorRound1Pool3.push(_stakerAddress);
		}else if(pool == 2){			
			investorRound1Pool2.push(_stakerAddress);
		}else if(pool == 1){			
			investorRound1Pool1.push(_stakerAddress);			
		}
  }

  	// Calculate the round 1 share
    function calculateTokenShareRound1() external {    	  	
    	//Algorithm for token share calculation    	
    	uint nanoPoolShare = nanoPoolWeight.div(8).mul(investorRound1Pool1.length);
    	uint microPoolShare = microPoolWeight.div(8).mul(investorRound1Pool2.length);
    	uint megaPoolShare = megaPoolWeight.div(8).mul(investorRound1Pool3.length);
    	uint gigaPoolShare = gigaPoolWeight.div(8).mul(investorRound1Pool4.length);
    	uint totalShare = nanoPoolShare.add(microPoolShare).add(megaPoolShare).add(gigaPoolShare);
    	shareRound1 = supplyRound1.div(totalShare);

    	//Providing ~20% extra allocation
    	shareRound1 = shareRound1.mul(120).div(100);    	
	}


	function allotTokenRound1() 
	external 
	onlyOwner {		
		uint userShare = shareRound1;
		InvestorInfo memory investorInfo;
		//allot Token to each investor from each stakingPool 
		for (uint256 s = 0; s <= investorRound1Pool1.length; s += 1){	
			investorInfo = InvestorInfo({
				eligibleToken: userShare,
				eligibleUSDC: convertTokenPriceToUSDC(userShare),
				poolWeight: nanoPoolWeight,
				purchasedToken: 0,				
				depositedUSDC: 0,
				extraUSDCPurchased: 0
			});			
			investorEligibleRound1[investorRound1Pool1[s]] = investorInfo;
		}

		userShare = shareRound1.mul(microPoolWeight).div(8);
		for (uint256 s = 0; s <= investorRound1Pool2.length; s += 1){	
			investorInfo = InvestorInfo({
				eligibleToken: userShare,
				eligibleUSDC: convertTokenPriceToUSDC(userShare),
				poolWeight: microPoolWeight,
				purchasedToken: 0,				
				depositedUSDC: 0,
				extraUSDCPurchased: 0
			});			
			investorEligibleRound1[investorRound1Pool2[s]] = investorInfo;
		}

		userShare = shareRound1.mul(megaPoolWeight).div(8);
		for (uint256 s = 0; s <= investorRound1Pool3.length; s += 1){	
			investorInfo = InvestorInfo({
				eligibleToken: userShare,
				eligibleUSDC: convertTokenPriceToUSDC(userShare),
				poolWeight: megaPoolWeight,
				purchasedToken: 0,				
				depositedUSDC: 0,
				extraUSDCPurchased: 0
			});			
			investorEligibleRound1[investorRound1Pool3[s]] = investorInfo;
		}

		userShare = shareRound1.mul(gigaPoolWeight).div(8);
		for (uint256 s = 0; s <= investorRound1Pool4.length; s += 1){	
			investorInfo = InvestorInfo({
				eligibleToken: userShare,
				eligibleUSDC: convertTokenPriceToUSDC(userShare),
				poolWeight: gigaPoolWeight,
				purchasedToken: 0,				
				depositedUSDC: 0,
				extraUSDCPurchased: 0
			});			
			investorEligibleRound1[investorRound1Pool4[s]] = investorInfo;
		}
	}

	// Calculate the round 2 share
    function calculateTokenShareRound2() onlyOwner internal {    	  	    	

    	shareRound2 = supplyRound2.div(investorRound2.length);

    	//Providing ~20% extra allocation
    	shareRound2 = shareRound2.mul(120).div(100);    	
	}

	function allotTokenRound2()
	external
	onlyOwner{		  	
		InvestorInfo memory investorInfo;
		//allot Token to each investor for round 2
		for (uint256 s = 0; s <= investorRound2.length; s += 1){	
			investorInfo = InvestorInfo({
				eligibleToken: shareRound2,
				eligibleUSDC: convertTokenPriceToUSDC(shareRound2),
				poolWeight: 0,
				purchasedToken: 0,				
				depositedUSDC: 0,
				extraUSDCPurchased: 0
			});			
			investorEligibleRound2[investorRound2[s]] = investorInfo;
		}

	}

	function calculateTokenShareRound3() internal onlyOwner{
		require(distributionRound1.add(distributionRound2) < fundingGoal, "No Round 3 required, funding goal reached!");

		shareRound3 = convertUSDCToToken(fundingGoal.sub(distributionRound2).sub(distributionRound1)).div(investorRound3.length);

    //Providing ~20% extra allocation
    shareRound3 = shareRound3.mul(120).div(100);
	}

	function allotTokenRound3()
	external
	onlyOwner{		  	
		InvestorInfo memory investorInfo;
		//allot Token to each investor for round 3
		for (uint256 s = 0; s <= investorRound3.length; s += 1){	
			investorInfo = InvestorInfo({
				eligibleToken: shareRound3,
				eligibleUSDC: convertTokenPriceToUSDC(shareRound3),
				poolWeight: 0,
				purchasedToken: 0,				
				depositedUSDC: 0,
				extraUSDCPurchased: 0
			});			
			investorEligibleRound3[investorRound3[s]] = investorInfo;
		}

	}


	function convertTokenPriceToUSDC(uint _userShare) public view returns(uint){
		return tokenPrice.mul(_userShare);
	}

	function convertUSDCToToken(uint _amount) public view returns(uint){
		return _amount.div(tokenPrice);
	}
}