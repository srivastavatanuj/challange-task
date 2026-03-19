pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  // IERC20
  mapping(address => mapping(address => uint256)) public allowances;
  address[] public holders;
  mapping(address => bool) internal isHolder;
  uint256 public dividendPerToken; // scaled by 1e18
  mapping(address => uint256) public dividendCreditedTo;
  mapping(address => uint256) public withdrawable;

  uint256 constant MULTIPLIER = 1e18;

  // ---------------- ERC20 ----------------

  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    allowances[msg.sender][spender] = value;
    return true;
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    _update(msg.sender);
    _update(to);

    require(balanceOf[msg.sender] >= value, "insufficient");

    balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
    balanceOf[to] = balanceOf[to].add(value);

    _updateHolder(msg.sender);
    _updateHolder(to);

    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    _update(from);
    _update(to);

    require(balanceOf[from] >= value, "insufficient");
    require(allowances[from][msg.sender] >= value, "allowance");

    allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);

    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);

    _updateHolder(from);
    _updateHolder(to);

    return true;
  }

  // ---------------- Mint / Burn ----------------

  function mint() external payable override {
    require(msg.value > 0, "no value");

    _update(msg.sender);

    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);

    _updateHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    _update(msg.sender);

    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "no balance");

    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);

    _updateHolder(msg.sender);

    dest.transfer(amount);
  }

  // ---------------- Holders ----------------

  function _updateHolder(address user) internal {
    if (balanceOf[user] > 0 && !isHolder[user]) {
      isHolder[user] = true;
      holders.push(user);
    } else if (balanceOf[user] == 0 && isHolder[user]) {
      isHolder[user] = false;


      for (uint i = 0; i < holders.length; i++) {
        if (holders[i] == user) {
          holders[i] = holders[holders.length - 1];
          holders.pop();
          break;
        }
      }
    }
  }

  function getNumTokenHolders() external view override returns (uint256) {
    return holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    require(index > 0 && index <= holders.length, "invalid");
    return holders[index - 1];
  }

  // ---------------- Dividends ----------------

  function recordDividend() external payable override {
    require(msg.value > 0, "no dividend");
    require(totalSupply > 0, "no supply");

    dividendPerToken = dividendPerToken.add(
      msg.value.mul(MULTIPLIER).div(totalSupply)
    );
  }

  function _update(address user) internal {
    uint256 owed = dividendPerToken.sub(dividendCreditedTo[user]);
    if (owed > 0) {
      uint256 payment = balanceOf[user].mul(owed).div(MULTIPLIER);
      withdrawable[user] = withdrawable[user].add(payment);
      dividendCreditedTo[user] = dividendPerToken;
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    uint256 owed = dividendPerToken.sub(dividendCreditedTo[payee]);
    uint256 pending = balanceOf[payee].mul(owed).div(MULTIPLIER);
    return withdrawable[payee].add(pending);
  }

  function withdrawDividend(address payable dest) external override {
    _update(msg.sender);

    uint256 amount = withdrawable[msg.sender];
    require(amount > 0, "nothing");

    withdrawable[msg.sender] = 0;

    dest.transfer(amount);
  }
}