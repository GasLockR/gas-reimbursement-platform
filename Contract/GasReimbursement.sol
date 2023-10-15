// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ActivityScoring.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GasReimbursement is ReentrancyGuard {
    ActivityScoring public activityScoring;
    address[] public projects;
    mapping(address => ProjectSettings) public projectSettings;
    mapping(address => mapping(address => uint)) public userReimbursement;  // project => user => reimbursement

    struct ProjectSettings {
        address projectAddress;
        string eventName;
        uint totalReimbursementAmount;
        uint reimbursementDeadline;
        uint reimbursementRatio;
        uint reimbursementLimit;
    }

    constructor(ActivityScoring _activityScoring) {
        activityScoring = _activityScoring;
    }

    function setParameters(
        address projectAddress,
        string memory eventName,
        uint totalReimbursementAmount,
        uint reimbursementDeadline,
        uint reimbursementRatio,
        uint reimbursementLimit
    ) public payable {
        require(msg.value >= totalReimbursementAmount, "Not enough ether sent for the reimbursement pool");
        ProjectSettings memory newSettings = ProjectSettings({
            projectAddress: projectAddress,
            eventName: eventName,
            totalReimbursementAmount: totalReimbursementAmount,
            reimbursementDeadline: reimbursementDeadline,
            reimbursementRatio: reimbursementRatio,
            reimbursementLimit: reimbursementLimit
        });
        projectSettings[projectAddress] = newSettings;
        projects.push(contractAddress);
    }

    //triggered by external script, monitoring events
    function updateReimbursement(
        address projectAddress,
        address userAddress,
        uint gasFee
    ) public {
        require(block.timestamp <= projectSettings[projectAddress].reimbursementDeadline, "Reimbursement deadline passed for updates");
        uint activity = activityScoring.getUserActivity(
            projectSettings[projectAddress].contractAddress,
            projectSettings[projectAddress].eventName,
            userAddress
        );
        uint reimbursementAmount = (activity * gasFee * projectSettings[projectAddress].reimbursementRatio) / 10000; // Assuming reimbursementRatio is a percentage
        userReimbursement[projectAddress][userAddress] += reimbursementAmount;
    }

    function checkReimbursement(address userAddress) public view returns (uint[] memory reimbursements, uint totalReimbursement) {
        reimbursements = new uint[](projects.length);
        totalReimbursement = 0;
        for (uint i = 0; i < projects.length; i++) {
            address projectAddress = projects[i];
            reimbursements[i] = userReimbursement[projectAddress][userAddress];
            totalReimbursement += reimbursements[i];
        }
    }

    function claimReimbursement(address userAddress) public nonReentrant {
        for (uint i = 0; i < projects.length; i++) {
            address projectAddress = projects[i];
            uint reimbursementAmount = userReimbursement[projectAddress][msg.sender];
            require(reimbursementAmount > 0, "No reimbursement available");
            userReimbursement[projectAddress][msg.sender] = 0;
            payable(msg.sender).transfer(reimbursementAmount);
        }
    }
}
