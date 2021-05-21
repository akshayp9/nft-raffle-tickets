// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract NftRaffleTicket is Ownable {
  using SafeMath for uint256; 
  using Address for address payable;
  string platformName;

  constructor(string memory _platformName){
    platformName = _platformName;
  }
  
  enum RaffleStatus {
    INITIALIZE,
    ONGOING,
    WINNER_NOT_DECLARED,
    WINNER_DECLARED,
    DRAW
  }

  struct Raffle {
    uint256 raffleId;
    string raffleName;
    address nftContract;
    uint256 token_id;
    uint256 ticketSize;
    uint256 ticketPrice;
    uint256 participants;
    uint256 min_ticketSize;
    address winner;
    uint endDate;
    address owner;
    RaffleStatus status;
  }

  uint platformFee = 1;
  uint256 public raffleTicketsLength = 0;
  mapping(uint256 => Raffle) public raffleTickets;
  mapping(uint256 => address) raffleParticipant;
  mapping(uint => uint[]) raffleTicketsById;
  mapping(address => uint[]) raffleTicketsByParticipant;
  mapping(address => mapping(uint => uint)) participantAmount;

////////////////////// External Function //////////////////////
  function raffleTicketCreated(
    string memory raffleName,
    address nftContract,
    uint256 token_id,
    uint256 ticketSize,
    uint256 ticketPrice,
    uint256 min_ticketSize,
    address payable fromAddress,
    uint endDate
  ) external returns(uint) {
    ERC721(nftContract).safeTransferFrom(fromAddress, address(this), token_id);
    uint raffleId = random();
    raffleTickets[raffleId] = Raffle (
      raffleId,
      raffleName,
      nftContract,
      token_id,
      ticketSize,
      ticketPrice,
      0,
      min_ticketSize,
      address(0),
      endDate,
      fromAddress,
      RaffleStatus(0)
    );
    raffleTicketsLength = raffleTicketsLength + 1;
    return raffleId;
  }


function enterParticipant(uint256 raffleId, uint256 numberOfTickets) external payable {
    require(block.timestamp <= raffleTickets[raffleId].endDate, "Raffle competition is Over");
    require(numberOfTickets > 0, "Minimum 1 Ticket should be there");
    require(msg.value >= (raffleTickets[raffleId].ticketPrice).mul(numberOfTickets), "Minimum Amount is Required");
    participantAmount[_msgSender()][raffleId] = (participantAmount[_msgSender()][raffleId]).add(msg.value);
    for (uint256 i = 0; i < numberOfTickets-1; i++) {
      uint ticketId = random();
      raffleTicketsById[raffleId].push(ticketId);
      raffleTicketsByParticipant[_msgSender()].push(ticketId);
      raffleTickets[raffleId].participants = raffleTickets[raffleId].participants + 1;
    }
    raffleTickets[raffleId].status = RaffleStatus(1);
}

function winnerSelected(uint256 id) external returns(address) {
    require(block.timestamp > raffleTickets[id].endDate, "Raffle competition is Not Over yet");
    require(raffleTickets[id].owner == msg.sender || owner() == msg.sender);
    if (raffleTickets[id].participants >= raffleTickets[id].min_ticketSize){
       uint[] memory ticketId = getRaffleTicketsByRaffle(id);
       uint randomPosition = uint(keccak256(abi.encodePacked(block.timestamp))) % ticketId.length;
       address winner = getRaffleParticipant(ticketId[randomPosition]);
       ERC721(raffleTickets[id].nftContract).safeTransferFrom(address(this), winner, raffleTickets[id].token_id);
       uint totalAmount = (raffleTickets[id].ticketPrice).mul(raffleTickets[id].participants);
       uint platformAmount = totalAmount.mul(platformFee).div(100);
       (bool success, ) = msg.sender.call{ value: totalAmount.sub(platformAmount) }("");
       require(success, "Address: unable to send value, recipient may have reverted");
       (bool ownerPay, ) = owner().call{ value: platformAmount }("");
       require(ownerPay, "Address: unable to send value, recipient may have reverted");
       raffleTickets[id].winner = winner;
       raffleTickets[id].status = RaffleStatus(3);
       return winner;
    } else {
      raffleTickets[id].status = RaffleStatus(4);
      ERC721(raffleTickets[id].nftContract).safeTransferFrom(address(this), _msgSender(), raffleTickets[id].token_id);
      raffleTickets[id].winner = address(0);
      return raffleTickets[id].winner;
  }
}

function claimUserdraw(uint id, address userAddress) external payable{
  require(raffleTickets[id].status == RaffleStatus(4));
  require(raffleParticipant[id] == msg.sender);
  require(raffleTickets[id].participants < raffleTickets[id].min_ticketSize);
  uint amount = participantAmount[userAddress][id];
  require(msg.value <= amount);
  (bool userWithdraw, ) = userAddress.call{ value: amount }("");
  require(userWithdraw, "Address: unable to send value, recipient may have reverted");
}

function changePlatformFee(uint amount) external onlyOwner {
  platformFee = amount;
}

function withdrawTokens(address _tokenAddress) public onlyOwner {
    IERC20 tokenAddress = IERC20(_tokenAddress);
    require(tokenAddress.transfer(owner(), tokenAddress.balanceOf(address(this))));
}

function withdraw(uint _amount) public onlyOwner {
    (bool extravalue, ) = owner().call{ value: _amount }("");
    require(extravalue, "Address: unable to send value, recipient may have reverted");
}

////////////////////// View Function //////////////////////
function getRaffleTicketsByUser(address userAddress) public view returns(uint[] memory){
  return raffleTicketsByParticipant[userAddress];
}

function getRaffleTicketsByRaffle(uint id) public view returns(uint[] memory){
  return raffleTicketsById[id];
} 

function getRaffleParticipant(uint id) public view returns (address){
  return raffleParticipant[id];
}

function raffleStatus(uint id) public view returns(RaffleStatus) {
    return raffleTickets[id].status;
}

function claimBalance(uint id, address userAddress) public view returns(uint) {
  if (raffleTickets[id].status == RaffleStatus(4)) {
    return participantAmount[userAddress][id];
  } else {
    return 0;
  }
}

function getRaffle(uint id) public view returns(Raffle memory) {
  return raffleTickets[id];
}

////////////////////// Internal Function //////////////////////

function random() private view returns (uint) {
    uint randomHash = uint(keccak256(abi.encodePacked(block.timestamp)));
    return randomHash;
} 
}