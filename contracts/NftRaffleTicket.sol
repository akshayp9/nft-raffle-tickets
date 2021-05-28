// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract NftRaffleTicket is Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private TicketId;
  using SafeMath for uint256; 
  using Address for address payable;
  string platformName;

  constructor(){
    platformName = "NFT Raffle Platform";
    TicketId.increment();
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
    uint256 nftId;
    uint256 nftPrice;
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
  uint[] raffleUniqueId;
  uint256 public raffleTicketsLength = 0;
  mapping(uint256 => Raffle) public raffleTickets;
  mapping(uint256 => address[]) raffleParticipant;
  mapping(uint => uint[]) public raffleTicketsById;
  mapping(address => uint[]) raffleTicketsByParticipant;
  mapping(uint => address) ticketIdByUser;
  mapping(address => mapping(uint => uint)) participantAmount;
  
  event RaffleTicketCreated(uint indexed raffleId, string raffleName, address nftContract, uint256 nftId, uint nftPrice, uint256 ticketSize, uint256 ticketPrice, uint256 min_ticketSize, address fromAddress, uint endDate, uint timestamp);
  event EnterParticipant(uint256 indexed raffleId, uint256 numberOfTickets, address userAddress, uint[] ticketId, uint timestamp);
  event WinnerSelected(uint256 indexed raffleId, address winnerAddress, uint256 ticketId, uint timestamp);
  
////////////////////// External Function //////////////////////
  function raffleTicketCreated(string memory raffleName, address nftContract, uint256 nftId, uint nftPrice, uint256 ticketSize, uint256 ticketPrice, uint256 min_ticketSize, address nftOwner, uint endDate) external returns(uint) {
    IERC721Receiver(address(this)).onERC721Received(nftContract, _msgSender(), nftId, abi.encodePacked(nftId));
    ERC721(nftContract).safeTransferFrom(nftOwner, address(this), nftId);
    TicketId.increment();
    uint raffleId = randomSelection(msg.sender).add(TicketId.current());
    raffleUniqueId.push(raffleId);
    raffleTickets[raffleId] = Raffle(raffleId, raffleName, nftContract, nftId, nftPrice, ticketSize, ticketPrice, 0, min_ticketSize, address(0), endDate, nftOwner, RaffleStatus(0));
    raffleTicketsLength = raffleTicketsLength + 1;
    emit RaffleTicketCreated(raffleId, raffleName, nftContract, nftId, nftPrice, ticketSize, ticketPrice, min_ticketSize, nftOwner, endDate, block.timestamp);
    return raffleId;
  }


function enterParticipant(uint256 raffleId, uint256 numberOfTickets) external payable {
    require(block.timestamp <= raffleTickets[raffleId].endDate, "Raffle competition is Over");
    require(numberOfTickets > 0, "Minimum 1 Ticket should be there");
    require(msg.value >= (raffleTickets[raffleId].ticketPrice).mul(numberOfTickets), "Minimum Amount is Required");
    raffleParticipant[raffleId].push(_msgSender());
    participantAmount[_msgSender()][raffleId] = (participantAmount[_msgSender()][raffleId]).add(msg.value);
    for (uint256 i = 0; i < numberOfTickets; i++) {
      TicketId.increment();
      uint ticketId = TicketId.current();
      raffleTicketsById[raffleId].push(ticketId);
      raffleTicketsByParticipant[_msgSender()].push(ticketId);
      ticketIdByUser[ticketId] = _msgSender();
      raffleTickets[raffleId].participants = raffleTickets[raffleId].participants + 1;
    }
    raffleTickets[raffleId].status = RaffleStatus(1);
    emit EnterParticipant(raffleId, numberOfTickets, _msgSender(), raffleTicketsByParticipant[_msgSender()], block.timestamp);
}

function winnerSelected(uint256 raffleId) external returns(address) {
    require(block.timestamp > raffleTickets[raffleId].endDate, "Raffle competition is Not Over yet");
    require(raffleTickets[raffleId].owner == msg.sender || owner() == msg.sender, "Caller is not Owner or Admin");
    if (raffleTickets[raffleId].participants >= raffleTickets[raffleId].min_ticketSize){
       uint winnerTicketId = raffleTicketsById[raffleId][randomSelection(msg.sender) % raffleTicketsById[raffleId].length];
       address winner = ticketIdByUser[winnerTicketId];
       ERC721(raffleTickets[raffleId].nftContract).safeTransferFrom(address(this), winner, raffleTickets[raffleId].nftId);
       uint totalAmount = (raffleTickets[raffleId].ticketPrice).mul(raffleTickets[raffleId].participants);
       uint platformAmount = totalAmount.mul(platformFee).div(100);
       (bool success, ) = _msgSender().call{ value: totalAmount.sub(platformAmount) }("");
       require(success, "Address: unable to send value, recipient may have reverted");
       (bool ownerPay, ) = owner().call{ value: platformAmount }("");
       require(ownerPay, "Address: unable to send value, recipient may have reverted");
       raffleTickets[raffleId].winner = winner;
       raffleTickets[raffleId].status = RaffleStatus(3);
       emit WinnerSelected(raffleId, winner, winnerTicketId, block.timestamp);
       return winner;
    } else {
      raffleTickets[raffleId].status = RaffleStatus(4);
      ERC721(raffleTickets[raffleId].nftContract).safeTransferFrom(address(this), raffleTickets[raffleId].owner, raffleTickets[raffleId].nftId);
      raffleTickets[raffleId].winner = address(0);
      emit WinnerSelected(raffleId, address(0), 0, block.timestamp);
      return raffleTickets[raffleId].winner;
  }
}

function claimUserdraw(uint raffleId, address userAddress, uint userIndex) external payable{
  require(raffleTickets[raffleId].status == RaffleStatus(4));
  require(raffleParticipant[raffleId][userIndex] == _msgSender());
  require(raffleTickets[raffleId].participants < raffleTickets[raffleId].min_ticketSize);
  uint amount = participantAmount[userAddress][raffleId];
  require(msg.value <= amount);
  (bool userWithdraw, ) = userAddress.call{ value: amount }("");
  require(userWithdraw, "Address: unable to send value, recipient may have reverted");
  participantAmount[userAddress][raffleId] = participantAmount[userAddress][raffleId].sub(amount);
}

function changePlatformFee(uint amount) external onlyOwner {
  platformFee = amount;
}

////////////////////// Withdraw Function //////////////////////
function withdrawTokens(address _tokenAddress) public onlyOwner {
    IERC20 tokenAddress = IERC20(_tokenAddress);
    require(tokenAddress.transfer(owner(), tokenAddress.balanceOf(address(this))));
}

function withdraw(uint _amount) public onlyOwner {
    (bool extravalue, ) = owner().call{ value: _amount }("");
    require(extravalue, "Address: unable to send value, recipient may have reverted");
}

function withdrawNft(address nftContract, uint nftId) public onlyOwner {
    ERC721(nftContract).safeTransferFrom(address(this), owner(), nftId);
}

////////////////////// View Function //////////////////////
function getRaffleTicketsByUser(address userAddress) public view returns(uint[] memory){
  return raffleTicketsByParticipant[userAddress];
}

function getRaffleTicketsByRaffle(uint id) public view returns(uint[] memory){
  return raffleTicketsById[id];
} 

function getRaffleParticipant(uint id) public view returns (address[] memory){
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

function getRaffleUniqueId() public view returns(uint[] memory) {
  return raffleUniqueId;
}

function onERC721Received( address _operator, address _from, uint256 _tokenId, bytes memory _data) public returns(bytes4) {
    return this.onERC721Received.selector;
}

////////////////////// Internal Function //////////////////////

function randomSelection(address userId) internal view returns(uint) {
    uint uniqueId = uint(keccak256(abi.encodePacked(block.timestamp + block.difficulty + 
    ((uint(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp)) + block.gaslimit + ((uint(keccak256(abi.encodePacked(userId)))) / (block.timestamp)) + block.number)));
    return (uniqueId - ((uniqueId / 1000000000000000000) * 1000000000000000000));
}
}
