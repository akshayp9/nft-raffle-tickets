const NftRaffleTicket = artifacts.require("NftRaffleTicket");
const Raffle = artifacts.require("Raffle");

module.exports = async function (deployer) {

  //  await deployer.deploy(Raffle);
   let newErc721 = await Raffle.deployed();
   let tokenId =  await newErc721.safeMint("0xc019560E072af1fb8C6B813f11349D9eEa1A021A");

  // await deployer.deploy(NftRaffleTicket, "Werewolf Raffle Platform");
  let nftRaffle = await NftRaffleTicket.deployed();
};