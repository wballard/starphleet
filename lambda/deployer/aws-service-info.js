#!/usr/bin/env node
/*
 Parses information for a serverless service and returns it.  
 Information is provided in the following format:

Service Information
service: aws-nodejs
stage: dev
region: us-east-1
stack: aws-nodejs-dev
api keys:
  None
endpoints:
  ANY - https://pxm9o1v966.execute-api.us-east-1.amazonaws.com/dev
  ANY - https://pxm9o1v966.execute-api.us-east-1.amazonaws.com/dev/{proxy+}
functions:
  api: aws-nodejs-dev-api

*/
const fs = require('fs');
const yaml = require('js-yaml')

// Constructor takes string returned from cli call `searverless deploy` 
function ServiceInfo (dataString) {
    this.data = {};
    this.dataString = dataString;
    this.parseDataString();
    return this;
};  
ServiceInfo.prototype.parseDataString = function (){
    var i, element, endpoint, method, url, apiGatewayID, urlParts;
    // Transform to valid Json
    // -- 1 Remove "Service Information" line
    lines = this.dataString.match(/[^\r\n]+/g);    
    lines.splice(0,1)
    var dataString = lines.join('\n')
    // -- 2 Add '-' before ANY in string to make endpoint values an array
    dataString = dataString.replace(/ANY/g, "- ANY")    
    console.log(dataString);

    this.data = yaml.safeLoad(dataString);
    
    // -- 3 parse enpoints to separate method and url
    //    Each array element currently has form 'ANY - https://pxm9o1v966.execute-api.us-east-1.amazonaws.com/dev'
    for( i = 0; i < this.data.endpoints.length; i++  ){
        element = this.data.endpoints[i];
        // Create endpoint object from string
        endpoint = element.split(" - ");
        method = endpoint[0];
        url = endpoint[1];
        endpoint = {
            method:method, 
            url:url
        };
        this.data.endpoints[i] = endpoint;
    }
    // -- 4  Set API Gateway ID
    url = this.data.endpoints[0].url.replace('https://','');
    urlParts = url.split(".");    
    this.data.apiGatewayID = urlParts[0];
    console.log(this.data)
    // -- 5 Set Api Gateway HOST and Url
    this.data.host = this.data.apiGatewayID + ".execute-api." + this.data.region + ".amazonaws.com";
    this.data.url = "https://" + this.data.Host;
    
};

ServiceInfo.prototype.getData = function(){
    console.log(this.data)
    return this.data;
}
ServiceInfo.prototype.getApiKey = function(){
    var apiKeys = this.data['api keys'];     
    var values = Object.keys(apiKeys).map(function(key) {
        return apiKeys[key];
    });
    return values[0]
}
module.exports = ServiceInfo;