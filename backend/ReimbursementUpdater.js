const { Requester, Validator } = require('@chainlink/external-adapter');
const ethers = require('ethers');
const abi = require('./ABI.json');

const customParams = { contractAddress: ['contractAddress'], eventName: ['eventName'] };

const createRequest = async (input, callback) => {
  const validator = new Validator(callback, input, customParams);
  const jobRunID = validator.validated.id;
  const contractAddress = validator.validated.data.contractAddress;
  const eventName = validator.validated.data.eventName;

  const provider = new ethers.providers.JsonRpcProvider('https://sepolia-rpc.scroll.io');
  const contract = new ethers.Contract(contractAddress, abi, provider);

  contract.on(eventName, async (userAddress, gasFee, event) => {
    const reimbursementContract = new ethers.Contract('0x7F43425E6B922e12e3b028Aa605E679502b12d7E', abi, provider);
    const tx = await reimbursementContract.updateReimbursement(contractAddress, userAddress, gasFee);
    await tx.wait();

    const response = {
      jobRunID: jobRunID,
      data: { txHash: tx.hash },
      result: { txHash: tx.hash },
      statusCode: 200
    };
    callback(response.status, Requester.success(jobRunID, response));
  });
};

exports.gcpservice = createRequest;
