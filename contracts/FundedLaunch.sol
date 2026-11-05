// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
 function balanceOf(address) external view returns(uint256);
 function transfer(address,uint256) external returns(bool);
 function transferFrom(address,address,uint256) external returns(bool);
 function approve(address,uint256) external returns(bool);
 function decimals() external view returns(uint8);
}
interface IPons {
 struct Socials {string twitter;string telegram;string discord;string website;string farcaster;}
 struct TokenParams {string name;string symbol;string logo;string description;Socials socials;address creatorFeeRecipient;uint16 creatorTaxBps;bool buybackEnabled;bytes32 expectedEconomics;bytes32 salt;}
 function launchFee() external view returns(uint256);
 function canLaunch(address) external view returns(bool);
 function approvedPairTokens(address)external view returns(bool);
 function pairTokenEconomics(address)external view returns(uint256,uint256,uint8);
 function setBuybackEnabled(address,bool)external;
}
interface IPonsRouter {
 function launchAndBuy(IPons.TokenParams calldata,uint256,address,uint256,uint256,address,address[] calldata) external payable returns(address token,address curve,uint256 tokensOut);
}
interface IEscrow {function claim() external;function claimToken(address)external;function balanceOf(address) external view returns(uint256);}
interface IBuybackVault{function release(address)external returns(uint256);}
interface ICurveSweep{function sweepFees(uint256)external;}
library Asset {function callToken(address token,bytes memory data)internal{require(token.code.length>0,"Asset has no code");(bool ok,bytes memory result)=token.call(data);require(ok&&(result.length==0||abi.decode(result,(bool))),"Asset transfer failed");}function send(address token,address to,uint256 n)internal{callToken(token,abi.encodeCall(IERC20.transfer,(to,n)));}function pull(address token,address from,uint256 n)internal{callToken(token,abi.encodeCall(IERC20.transferFrom,(from,address(this),n)));}function approve(address token,address to,uint256 n)internal{callToken(token,abi.encodeCall(IERC20.approve,(to,n)));}}
abstract contract Guard {
 uint256 private entered;
 modifier locked(){require(entered==0,"Reentrancy");entered=1;_;entered=0;}
 function pay(address to,uint256 value) internal{(bool ok,)=to.call{value:value}("");require(ok,"Payment failed");}
}

/// Eligibility is selected off-chain by the immutable operator. Published allocations are immutable.
contract RewardPool is Guard {
 address public immutable operator;address public immutable asset;
 struct Epoch{bytes32 root;uint256 remaining;string uri;}
 Epoch[] public epochs;uint256 public reserved;
 mapping(uint256=>mapping(address=>bool))public claimed;
 event EpochPublished(uint256 indexed epoch,bytes32 root,uint256 amount,string uri);
 event RewardClaimed(uint256 indexed epoch,address indexed account,uint256 amount);
 constructor(address op,address quote){require(op!=address(0),"Zero operator");operator=op;asset=quote;}
 receive()external payable{require(asset==address(0),"ERC20 pool");}
 function balance()public view returns(uint256){return asset==address(0)?address(this).balance:IERC20(asset).balanceOf(address(this));}
 function epochCount()external view returns(uint256){return epochs.length;}
 function publish(bytes32 root,uint256 amount,string calldata uri)external{
  require(msg.sender==operator,"Only operator");require(root!=0&&amount>0&&bytes(uri).length>0,"Empty epoch");
  require(amount<=balance()-reserved,"Unfunded");reserved+=amount;epochs.push(Epoch(root,amount,uri));emit EpochPublished(epochs.length-1,root,amount,uri);
 }
 function claim(uint256 epoch,uint256 amount,bytes32[] calldata proof)external locked{
  require(amount>0&&!claimed[epoch][msg.sender],"Already claimed or zero");
  bytes32 h=keccak256(abi.encode(block.chainid,address(this),epoch,msg.sender,amount));
  for(uint256 i;i<proof.length;i++)h=h<proof[i]?keccak256(abi.encodePacked(h,proof[i])):keccak256(abi.encodePacked(proof[i],h));
  Epoch storage e=epochs[epoch];require(h==e.root&&amount<=e.remaining,"Invalid proof");
  claimed[epoch][msg.sender]=true;e.remaining-=amount;reserved-=amount;if(asset==address(0))pay(msg.sender,amount);else Asset.send(asset,msg.sender,amount);emit RewardClaimed(epoch,msg.sender,amount);
 }
}

/// Locks tokens purchased in the opening buy, not a preminted allocation from Pons's supply.
contract PurchaseVesting is Guard {
 address public immutable coordinator;address public immutable beneficiary;uint256 public immutable duration;
 address public token;uint256 public allocation;uint256 public start;uint256 public released;
 constructor(address person,uint256 secondsLocked){coordinator=msg.sender;beneficiary=person;duration=secondsLocked;}
 function initialize(address asset)external{require(msg.sender==coordinator&&token==address(0),"Initialization");uint256 n=IERC20(asset).balanceOf(address(this));require(n>0,"Empty purchase");token=asset;allocation=n;start=block.timestamp;}
 function claimable()public view returns(uint256){if(start==0)return 0;uint256 elapsed=block.timestamp-start;if(elapsed>duration)elapsed=duration;return allocation*elapsed/duration-released;}
 function claim()external locked{require(msg.sender==beneficiary,"Only beneficiary");uint256 n=claimable();require(n>0,"Nothing vested");released+=n;require(IERC20(token).transfer(beneficiary,n),"Transfer failed");}
}

/// Only net ETH actually received from Pons escrow is split. No promised APR or automatic eligibility.
contract FeeSplitter is Guard {
 address public immutable escrow;address public immutable creator;address public immutable treasury;address public immutable asset;address public immutable factory;address public immutable buybackVault;address public immutable coordinator;
 address public immutable holderRewards;address public immutable traderRewards;address public launchToken;address public curve;
 mapping(address=>uint256)public credit;uint256 public accounted;uint256 public totalReceived;
 constructor(address e,address c,address t,address h,address r,address a,address f,address v){escrow=e;creator=c;treasury=t;holderRewards=h;traderRewards=r;asset=a;factory=f;buybackVault=v;coordinator=msg.sender;}
 receive()external payable{require(asset==address(0),"ERC20 splitter");}
 function initialize(address t,address cv)external{require(msg.sender==coordinator&&launchToken==address(0),"Initialization");launchToken=t;curve=cv;}
 function balance()public view returns(uint256){return asset==address(0)?address(this).balance:IERC20(asset).balanceOf(address(this));}
 function sync()public{uint256 n=balance()-accounted;if(n==0)return;accounted+=n;totalReceived+=n;uint256 h=n*50/100;uint256 r=n*30/100;uint256 c=n*10/100;credit[holderRewards]+=h;credit[traderRewards]+=r;credit[creator]+=c;credit[treasury]+=n-h-r-c;}
 function collectEscrow()external locked{if(asset==address(0))IEscrow(escrow).claim();else IEscrow(escrow).claimToken(asset);sync();}
 function release(address recipient)external locked{sync();uint256 n=credit[recipient];require(n>0,"Nothing accrued");credit[recipient]=0;accounted-=n;if(asset==address(0))pay(recipient,n);else Asset.send(asset,recipient,n);}
 function setBuyback(bool enabled)external{require(msg.sender==creator,"Only creator");IPons(factory).setBuybackEnabled(launchToken,enabled);}
 function releaseBuyback()external locked{require(msg.sender==creator&&launchToken!=asset,"Only creator");IBuybackVault(buybackVault).release(launchToken);IEscrow(escrow).claimToken(launchToken);uint256 n=IERC20(launchToken).balanceOf(address(this));if(n>0)Asset.send(launchToken,creator,n);}
 function sweepCurveFees()external locked{require(msg.sender==creator,"Only creator");ICurveSweep(curve).sweepFees(0);}
}

/// Native and approved ERC20 funded launch policy. Pons retains control of its own protocol configuration.
contract FundedLaunch is Guard {
 address public immutable factory;address public immutable router;address public immutable escrow;address public immutable treasury;address public immutable operator;address public immutable buybackVault;
 RewardPool public immutable holderRewards;RewardPool public immutable traderRewards;
 mapping(address=>address)public holderRewardsFor;mapping(address=>address)public traderRewardsFor;
 uint256 public immutable minSeed;uint256 public immutable duplicateBond;
 struct Request{string name;string symbol;string logo;string description;IPons.Socials socials;uint256 configId;uint256 seed;uint256 minTokensOut;uint16 creatorTaxBps;uint32 vestDays;bytes32 expectedEconomics;bytes32 salt;uint256 deadline;address pairToken;bool buybackEnabled;address[] exemptions;}
 struct Launch{address token;address curve;address creator;address vesting;address splitter;string name;string symbol;uint256 seed;uint256 tokensBought;uint256 createdAt;uint256 bond;bool refunded;address pairToken;uint8 quoteDecimals;bool buybackEnabled;}
 Launch[]public launches;mapping(bytes32=>uint256)public tickerCount;
 event FundedLaunchCreated(uint256 indexed id,address indexed token,address indexed creator,address curve,address vesting,address splitter,uint256 requestedSeed,uint256 tokensBought);
 constructor(address f,address r,address e,address t,address op,uint256 minimum,uint256 bond,address vault){require(f.code.length>0&&r.code.length>0&&e.code.length>0&&t!=address(0)&&op!=address(0)&&minimum>0&&vault.code.length>0,"Configuration");factory=f;router=r;escrow=e;treasury=t;operator=op;buybackVault=vault;minSeed=minimum;duplicateBond=bond;holderRewards=new RewardPool(op,address(0));traderRewards=new RewardPool(op,address(0));holderRewardsFor[address(0)]=address(holderRewards);traderRewardsFor[address(0)]=address(traderRewards);}
 receive()external payable{require(msg.sender==router,"Router refunds only");}
 function count()external view returns(uint256){return launches.length;}
 function normalize(string memory symbol)public pure returns(string memory){bytes memory b=bytes(symbol);require(b.length>0&&b.length<=10,"Ticker length");for(uint256 i;i<b.length;i++){uint8 c=uint8(b[i]);if(c>=97&&c<=122)c-=32;require((c>=65&&c<=90)||(c>=48&&c<=57),"Ticker characters");b[i]=bytes1(c);}return string(b);}
 function bondFor(string memory symbol)public view returns(uint256){return tickerCount[keccak256(bytes(normalize(symbol)))]==0?0:duplicateBond;}
 function launch(Request calldata q)external payable locked returns(address token,address curve){
  require(block.timestamp<=q.deadline,"Expired");require(IPons(factory).canLaunch(address(this)),"Pons gate closed");
  bool native=q.pairToken==address(0);uint8 decimals=18;
  if(!native){require(IPons(factory).approvedPairTokens(q.pairToken),"Pair not approved");(uint256 phantom,uint256 threshold,uint8 d)=IPons(factory).pairTokenEconomics(q.pairToken);require(phantom>0&&threshold>0&&IERC20(q.pairToken).decimals()==d,"Pair economics");require(q.seed>=threshold/100,"Pair minimum funding");decimals=d;}else require(q.seed>=minSeed,"Native minimum funding");
  require(q.seed>0&&q.minTokensOut>0&&q.exemptions.length<=32,"Funding or minimum output");require(q.vestDays>=30&&q.vestDays<=730,"Vesting policy");require(q.creatorTaxBps<=300,"Tax policy");
  require(bytes(q.name).length>0&&bytes(q.name).length<=64&&bytes(q.logo).length>0&&bytes(q.logo).length<=512&&bytes(q.description).length<=2048,"Metadata");
  string memory symbol=normalize(q.symbol);bytes32 ticker=keccak256(bytes(symbol));uint256 bond=tickerCount[ticker]==0?0:duplicateBond;
  uint256 fee=IPons(factory).launchFee();require(msg.value==fee+(native?q.seed:0)+bond,"Incorrect funding");uint256 previous=address(this).balance-msg.value;
  PurchaseVesting vest=new PurchaseVesting(msg.sender,uint256(q.vestDays)*1 days);
  if(holderRewardsFor[q.pairToken]==address(0)){holderRewardsFor[q.pairToken]=address(new RewardPool(operator,q.pairToken));traderRewardsFor[q.pairToken]=address(new RewardPool(operator,q.pairToken));}
  FeeSplitter splitter=new FeeSplitter(escrow,msg.sender,treasury,holderRewardsFor[q.pairToken],traderRewardsFor[q.pairToken],q.pairToken,factory,buybackVault);
  uint256 previousQuote;if(!native){previousQuote=IERC20(q.pairToken).balanceOf(address(this));Asset.pull(q.pairToken,msg.sender,q.seed);require(IERC20(q.pairToken).balanceOf(address(this))==previousQuote+q.seed,"Transfer tax unsupported");Asset.approve(q.pairToken,router,0);Asset.approve(q.pairToken,router,q.seed);}
  IPons.TokenParams memory params=IPons.TokenParams(q.name,symbol,q.logo,q.description,q.socials,address(splitter),q.creatorTaxBps,q.buybackEnabled,q.expectedEconomics,q.salt);
  uint256 tokensBought;
  (token,curve,tokensBought)=IPonsRouter(router).launchAndBuy{value:fee+(native?q.seed:0)}(params,q.configId,q.pairToken,q.seed,q.minTokensOut,address(vest),q.exemptions);
  require(token.code.length>0&&curve.code.length>0&&tokensBought>=q.minTokensOut,"Invalid Pons result");
  splitter.initialize(token,curve);
  if(!native){Asset.approve(q.pairToken,router,0);uint256 quoteRefund=IERC20(q.pairToken).balanceOf(address(this))-previousQuote;if(quoteRefund>0)Asset.send(q.pairToken,msg.sender,quoteRefund);}
  vest.initialize(token);require(vest.allocation()>=q.minTokensOut,"Purchase not delivered");
  tickerCount[ticker]++;launches.push(Launch(token,curve,msg.sender,address(vest),address(splitter),q.name,symbol,q.seed,tokensBought,block.timestamp,bond,false,q.pairToken,decimals,q.buybackEnabled));
  emit FundedLaunchCreated(launches.length-1,token,msg.sender,curve,address(vest),address(splitter),q.seed,tokensBought);
  uint256 refund=address(this).balance-previous-bond;if(refund>0)pay(msg.sender,refund);
 }
 function refundBond(uint256 id)external locked{Launch storage l=launches[id];require(msg.sender==l.creator&&!l.refunded&&l.bond>0&&block.timestamp>=l.createdAt+7 days,"Bond unavailable");l.refunded=true;pay(msg.sender,l.bond);}
}
