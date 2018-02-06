#!/usr/bin/env node
const execSync = require('child_process').execSync;
const Mustache = require('mustache')
var fs = require('fs');
var program = require('commander');
var orders = require('./orders') 
var serviceInfo = require('./aws-service-info')

// Establish command api
var appDirValue
program
    .version('0.1.0')
    .option('-p, --path <absolute_path>', 'Absolute path to directory of app to deploy')
    .option('-r, --runtime <runtime>', 'AWS platform runtime: node6.10 or node4.3' )
    .option('-o, --orders_file <orders_file>', 'Path to the orders file for the app being deployed' )
    .option('-s, --service <service>', 'Name of the service being deployed' )
    .option('-n, --container_name <container_name>', 'The name of the lxc container in which we are running' );

// Parse the arguments passed to the cli
program.parse(process.argv);

// Require user to specify directory to deploy
if (typeof program.path == 'undefined'){
    console.error('You must specify the directory where the applicaiton to deploy is located');
    process.exit(1)
}

if (typeof program.runtime == 'undefined'){
    console.log('You must specify the runtime platform to deploy to.  Currently support nodejs6.10 and nodejs4.3')
    process.exit(1)
}

if (program.runtime != 'nodejs6.10' && program.runtime != 'nodejs4.3'){
    console.log('Supported runtimes values are nodejs6.10 and nodejs4.3. You entered \'' + program.runtime + '\'')
    process.exit(1)
}

if (program.runtime != 'nodejs6.10' && program.runtime != 'nodejs4.3'){
    console.log('Supported runtimes values are nodejs6.10 and nodejs4.3. You entered \'' + program.runtime + '\'')
    process.exit(1)
}

if (typeof program.orders_file == 'undefined'){
    console.log('You must specify the orders file for the application being deployed')
    process.exit(1)
}

if (! fs.existsSync(program.orders_file) ){
    console.log('The orders file path you specified does not exist: ' + program.orders_file)
    process.exit(1)
}

if (typeof program.service == 'undefined'){
    console.log('You must specify service name using the --service or -s option')
    process.exit(1)
}

if (typeof program.container_name == 'undefined'){
    console.log('You must specify service name using the --service or -s option')
    process.exit(1)
}

// --- Done with Parameter Validation

// 1 - Copy build App directory to temp working directory
const tmpDir = "tmp_app"
console.log( "Copying app directory '"+ program.path +"' to new temporary deploy directory ")
var cmd = "cp -a " + program.path + " ./" + tmpDir;
stdout = execSync(cmd);

// 2 - Read Order File
console.log("### READ ORDER FILE")
console.log("    ")
envVars = orders.getVars(program.orders_file)

// 3 - Create Serverless Framework config file in app root
console.log('Writing  Serverless config to root app directory')
yaml = fs.readFileSync("templates/aws-node-serverless.yml.mst", 'utf-8')

var stage = program.container_name
// Remove service name from stage name, since this is part of the api gatway name
stage = stage.replace(program.service,"");
// Replace dash with X because dashes are not allowed in lambda stage names
stage = stage.replace(/\-/g,'X');
// Replace Underscore with Y because underscore is not allowed in API Gateway names
stage = stage.replace(/_/g,'Y');

//   - setup template
var data = {
    stage: stage, 
    bucket: "starphleet-lambda-deploys", 
    region: "us-east-1",
    runtime: program.runtime,
    hasEnvVars: envVars.length > 0,
    environment: envVars,
    service_name: program.service    
    
}
console.log(data);

yaml = Mustache.render(yaml, data )

//  - Write the config file  
fs.writeFileSync(tmpDir + '/serverless.yml',yaml);

// 4 - Add lambda handler (index.hanlder) file to the app root
// Note: expects express app to be available in app.js file in the apps root directory
console.log("Copying lambda handler file to app root")
stdout = execSync("cp -a ./templates/aws-node-handler.js ./" + tmpDir + "/index.js", {stdio:[0,1,2]});

// 5 - Install serverless-http package needed to use express app in lambda
console.log("Installing serverless-http node package", {stdio:[0,1,2]})
 stdout = execSync("npm i serverless-http", { cwd: tmpDir, stdio:[0,1,2]});

// 6 - Call serverless deploy on the temp app directory
console.log("Deploying app to Lambda")
// heroku hack - remove .heroku symlinks which contains symlinks that will break deploy
 stdout = execSync("rm -rf .heroku", { cwd: tmpDir, stdio:[0,1,2] });
// end heroku hack
 stdout = execSync("serverless deploy", { cwd: tmpDir, stdio:[0,1,2] });

// 7 - Get meta data of AWS service and write it to file that can be sourced by shell scripts
//   - Get output of serverless inco command
var info = execSync("serverless info", { cwd: tmpDir }).toString('utf8');

//   - Prase serverless info data
ServiceInfo = new serviceInfo(info);
var serviceData = ServiceInfo.getData();

// Write files with var values to shared data folder
fs.writeFileSync( '/var/data/' + program.container_name +"-endpoint.host", serviceData.host);
fs.writeFileSync( '/var/data/' + program.container_name +"-endpoint.stage", serviceData.stage);
fs.writeFileSync( '/var/data/' + program.container_name +"-endpoint.key", ServiceInfo.getApiKey());


// 7 - Remove the temp app directory
// stdout = execSync("rm -rf ./" + tmpDir, { stdio:[0,1,2] })
console.log('Done   ')

