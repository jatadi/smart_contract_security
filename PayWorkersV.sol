// SPDX-License-Identifier: GPL-3.0
/*
 * This contract is a financial transaction contract for paying out workers.
 * @author Tadija Ciric
 * @version 1.01 12/10/2022
 */

pragma solidity ^0.8.17;

/* Vulnerable */

contract PayWorkers {
    
    address owner;

    event payedOut(address a, uint amount, uint contractBalance);
    
    /* Employer is the owner of the contract.*/
    constructor() {
        owner = msg.sender;
    }

    /* Define Worker object */
    struct Worker {
        address payable walletAddress;
        string name;
        uint payOutTime;
        uint amount;
        bool withdrawable;
        bool deservedBonus;
    }

    /* Initializing an array of Workers */
    Worker[] public workers;

    /* Adds worker to the workers array with according variables
    *  @param walletAddress  
    *  @param name
    *  @param payOutTime
    *  @param amount
    *  @param withdraw
    *  @param deservedBonus
    */
    function addWorker(address payable walletAddress, string memory name, uint payOutTime, uint amount, bool withdrawable, bool deservedBonus) public onlyOwner {
        workers.push(Worker(
            walletAddress,
            name,
            payOutTime,
            amount,
            withdrawable,
            deservedBonus
        ));
    }

    /* Returns the index of the worker in the array workers, given the worker's address
    * @param walletAdress  address of the worker to find
    * @return uint  index of found worker
    */
    function getWorker(address walletAddress) view private returns(uint) {
        for(uint i = 0; i < workers.length; i++) {
            if(workers[i].walletAddress == walletAddress) {
                return i;
            }
        }
        return 0;
    }

    /* Returns the balance of Ether in the contract
    * @returns uint balance 
    * Example of function visibility vulnerability
    */
    function balanceOf() public view returns(uint) {
        return address(this).balance;
    }

    /* Maps an address to an integer value */
    mapping (address => uint) private getBalance;

    /* Helper method to update the worker's amout after deposit
    * @param walletAdress  address of the worker to update
    */
    function payWorker(address walletAddress) private {
        for (uint i = 0; i < workers.length; i++) {
            if(workers[i].walletAddress == walletAddress) {
                workers[i].amount += msg.value;
                emit payedOut(walletAddress, msg.value, balanceOf());
            }
        }
    }

    /* Deposits funds to a specific worker's address, increasing the balance of the contract
    * @param walletAdress  address to deposit to
    */
    function deposit(address walletAddress) public payable {
        payWorker(walletAddress);
    }

    /* Pays all workers an equal amount 
    * @param totalPay   total amount in Wei to be split between workers
    * Wei to Ether ratio - 1 : 1000000000000000000
    * @return bool      returns true if the payment is successfull
    * Integer overflow vulnerability
    */
    function payEqual(uint totalPay) public payable returns(bool){
        uint size = workers.length;
        uint equalPay = totalPay/size;
        require(size > 0);
        require(totalPay > 0 && owner.balance > totalPay);
        for(uint i = 0; i < size; i++) {
            workers[i].amount += equalPay;
            workers[i].walletAddress.transfer(equalPay);
        }
    return true;
    }

    /* Pays workers who are eligible for a bonus 
    * @param totalBonus   total bonus amount in Wei to be split between workers who are eligible
    * Wei to Ether ratio - 1 : 1000000000000000000
    * Unchecked send vulnerability example
    */
    function payBonus(uint totalBonus) public payable {
        uint endOfYear = 1672531201;                       
        bool paidBonus = false;
        uint bonusAmount = totalBonus/workers.length;
        for (uint i = 0; i < workers.length; i++) {
            paidBonus = false;
            if(workers[i].payOutTime > endOfYear && workers[i].withdrawable && workers[i].deservedBonus && !(paidBonus)) {
                (workers[i].walletAddress.send(bonusAmount));
                paidBonus = true;
                workers[i].amount += bonusAmount;
                
            }
        }
    }

    /* Returns true if a worker is able to withdraw the amount in his/her account
    * A worker can withdraw only after the release time passed
    * @param walletAdress  address of the worker to test
    * @return bool   true if able to withdraw, false if unable to withdraw
    */
    function canWithdraw(address walletAddress)  public returns(bool) {
        uint i = getWorker(walletAddress);
        require(block.timestamp > workers[i].payOutTime, "You can't withdraw yet!");
        if(block.timestamp > workers[i].payOutTime) {
            workers[i].withdrawable = true;
            return true;
        }
        return false;
    }

    /* Withdraws the amount of Ether to the worker's address 
    * @param walletAdress  address of the worker to withdraw
    */
    function withdraw(address payable walletAddress) public payable {
        uint i = getWorker(walletAddress);
        require(msg.sender == workers[i].walletAddress, "You must be a worker to withdraw!");
        require(workers[i].withdrawable == true, "You are not able to withdraw money right now!");
        workers[i].walletAddress.transfer(workers[i].amount);
        workers[i].amount -= msg.value;
    }

    /* Withdraws all Ether from the worker's address 
    * @param walletAdress  address of the worker to withdraw
    * Reentrancy vulnerability avoided
    */
    function withdrawAll(address payable walletAddress) public payable {
        uint i = getWorker(walletAddress);
        require(msg.sender == workers[i].walletAddress, "You must be a worker to withdraw!");
        require(workers[i].withdrawable == true, "You need to wait for your pay-out time");
        uint amountToWithdraw = getBalance[msg.sender];
        if(amountToWithdraw > 0) {
            msg.sender.call{value:(getBalance[msg.sender])};
            getBalance[msg.sender] = 0;
        }
    }
}