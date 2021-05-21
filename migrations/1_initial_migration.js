const NftRaffleTicket = artifacts.require("NftRaffleTicket");

module.exports = function (deployer) {
  deployer.deploy(NftRaffleTicket, "Werewolf Raffle Platform");
};
