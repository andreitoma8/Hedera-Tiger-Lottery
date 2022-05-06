console.clear();
require("dotenv").config();
const {
    Client,
    AccountId,
    PrivateKey,
    TokenCreateTransaction,
    FileCreateTransaction,
    FileAppendTransaction,
    ContractCreateTransaction,
    ContractFunctionParameters,
    TokenUpdateTransaction,
    ContractExecuteTransaction,
    TokenInfoQuery,
    AccountBalanceQuery,
    Hbar,
    TransactionRecordQuery,
    ContractInfoQuery,
    TokenType,
    TokenSupplyType,
    TokenAssociateTransaction,
    ContractId
} = require("@hashgraph/sdk");
const fs = require("fs");

const operatorId = AccountId.fromString(process.env.OPERATOR_ID);
const operatorKey = PrivateKey.fromString(process.env.OPERATOR_PVKEY);
const treasuryId = AccountId.fromString(process.env.TREASURY_ID);
const treasuryKey = PrivateKey.fromString(process.env.TREASURY_PVKEY);

const client = Client.forTestnet().setOperator(operatorId, operatorKey);

const supplyKey = PrivateKey.generate();
const adminKey = PrivateKey.generate();
const pauseKey = PrivateKey.generate();
const freezeKey = PrivateKey.generate();
const wipeKey = PrivateKey.generate();

async function main() {
    console.log(`STEP 1 ===================================`);
    const bytecode = fs.readFileSync("./TigerLottery_sol_TigerLottery.bin");
    console.log(`- Done \n`);

    console.log(`STEP 2 ===================================`);
    //Create a file on Hedera and store the contract bytecode
    const fileCreateTx = new FileCreateTransaction().setKeys([treasuryKey]).freezeWith(client);
    const fileCreateSign = await fileCreateTx.sign(treasuryKey);
    const fileCreateSubmit = await fileCreateSign.execute(client);
    const fileCreateRx = await fileCreateSubmit.getReceipt(client);
    const bytecodeFileId = fileCreateRx.fileId;
    console.log(`- The smart contract bytecode file ID is ${bytecodeFileId}`);

    const fileAppendTx = new FileAppendTransaction()
        .setFileId(bytecodeFileId)
        .setContents(bytecode)
        .setMaxChunks(10)
        .freezeWith(client);
    const fileAppendSign = await fileAppendTx.sign(treasuryKey);
    const fileAppendSubmit = await fileAppendSign.execute(client);
    const fileAppendRx = await fileAppendSubmit.getReceipt(client);
    console.log(`- Content added: ${fileAppendRx.status} \n`);

    // Create a fungible token mock for Mingo
    const tokenCreateTx = await new TokenCreateTransaction()
        .setTokenName("Mingo Token")
        .setTokenSymbol("MINGO")
        .setDecimals(0)
        .setInitialSupply(10000)
        .setTreasuryAccountId(operatorId) // set to operator for msg.sender to work
        .setAdminKey(operatorKey)
        .setSupplyKey(operatorKey)
        .freezeWith(client)
        .sign(operatorKey);
    const tokenCreateSubmit = await tokenCreateTx.execute(client);
    const tokenCreateRx = await tokenCreateSubmit.getReceipt(client);
    const tokenId = tokenCreateRx.tokenId;
    const tokenAddressSol = tokenId.toSolidityAddress();
    console.log(`- Token ID: ${tokenId}`);
    console.log(`- Token ID in Solidity format: ${tokenAddressSol}`);

    // Create the smart contract
    const contractInstantiateTx = new ContractCreateTransaction()
        .setBytecodeFileId(bytecodeFileId)
        .setGas(3000000)
        .setConstructorParameters(new ContractFunctionParameters().addAddress(tokenAddressSol));
    const contractInstantiateSubmit = await contractInstantiateTx.execute(client);
    const contractInstantiateRx = await contractInstantiateSubmit.getReceipt(client);
    const contractId = contractInstantiateRx.contractId;
    const contractAddress = contractId.toSolidityAddress();
    console.log(`- The smart contract ID is: ${contractId}`);
    console.log(`- The smart contract ID in Solidity format is: ${contractAddress} \n`);

    //Execute a contract function (associate)
    const contractExecTx1 = await new ContractExecuteTransaction()
        .setContractId(contractId)
        .setGas(3000000)
        .setFunction("tokenAssociate")
        .freezeWith(client);
    const contractExecSubmit1 = await contractExecTx1.execute(client);
    const contractExecRx1 = await contractExecSubmit1.getReceipt(client);
    console.log(`- Token association with Contract: ${contractExecRx1.status.toString()} \n`);
    const contractExecRec1 = await contractExecSubmit1.getRecord(client);
    const recQuery1 = await new TransactionRecordQuery()
        .setTransactionId(contractExecRec1.transactionId)
        .setIncludeChildren(true)
        .execute(client);

    //Create NFT Collection
    let nftCreate = await new TokenCreateTransaction()
        .setTokenName("Tiger Tickets")
        .setTokenSymbol("TICKET")
        .setTokenType(TokenType.NonFungibleUnique)
        .setDecimals(0)
        .setInitialSupply(0)
        .setTreasuryAccountId(treasuryId)
        .setSupplyType(TokenSupplyType.Infinite)
        .setAdminKey(adminKey)
        .setSupplyKey(ContractId.fromString(contractId))
        .setFreezeKey(freezeKey)
        .setWipeKey(wipeKey)
        .freezeWith(client)
        .sign(treasuryKey)

    const nftCreateTxSign = await nftCreate.sign(adminKey)
    const nftCreateSubmit = await nftCreateTxSign.execute(client)
    const nftCreateRx = await nftCreateSubmit.getReceipt(client)
    const nftId = nftCreateRx.tokenId
    const nftAddressSol = nftId.toSolidityAddress();
    console.log(`- NFT ID: ${nftId}`);
    console.log(`- NFT ID in Solidity format: ${nftAddressSol}`);

    // Update the NFT so the smart contract manages the supply
    const tokenUpdateTx = await new TokenUpdateTransaction()
        .setTokenId(nftId)
        .setSupplyKey(contractId)
        .setTreasuryAccountId(contractId)
        .freezeWith(client)
        .sign(adminKey);
    const tokenUpdateSubmit = await tokenUpdateTx.execute(client);
    const tokenUpdateRx = await tokenUpdateSubmit.getReceipt(client);
    console.log(`- NFT update status: ${tokenUpdateRx.status}`);


    //Execute a contract function Create Lottery
    const contractExecTx2 = await new ContractExecuteTransaction()
        .setContractId(contractId)
        .setGas(3000000)
        .setFunction("createLottery", new ContractFunctionParameters().addAddress(nftAddressSol))
        .freezeWith(client);
    const contractExecSubmit2 = await contractExecTx2.execute(client);
    const contractExecRx2 = await contractExecSubmit2.getReceipt(client);
    console.log(`- Lottery creation: ${contractExecRx2.status.toString()} \n`);
    const contractExecRec2 = await contractExecSubmit2.getRecord(client);
    const recQuery2 = await new TransactionRecordQuery()
        .setTransactionId(contractExecRec2.transactionId)
        .setIncludeChildren(true)
        .execute(client);


    //Execute a contract function Buy Entry Ticket
    const contractExecTx3 = await new ContractExecuteTransaction()
        .setContractId(contractId)
        .setGas(3000000)
        .setFunction("buyEntryTicket", new ContractFunctionParameters().addInt64(1).addBytesArray(["QmNPCiNA3Dsu3K5FxDPMG5Q3fZRwVTg14EXA92uqEeSRXn"]))
        .freezeWith(client);
    const contractExecSubmit3 = await contractExecTx3.execute(client);
    const contractExecRx3 = await contractExecSubmit3.getReceipt(client);
    console.log(`- Token buy status: ${contractExecRx3.status.toString()} \n`);
    const contractExecRec3 = await contractExecSubmit3.getRecord(client);
    const recQuery3 = await new TransactionRecordQuery()
        .setTransactionId(contractExecRec3.transactionId)
        .setIncludeChildren(true)
        .execute(client);

}
main()