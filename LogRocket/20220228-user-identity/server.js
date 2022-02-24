#! /usr/local/bin/node

// This application uses express as its web server
// for more info, see: http://expressjs.com
var express = require("express")

// create a new express server
var app = express()

// To keep track of users
var session = require("express-session")


var ethers = require("ethers")


// serve the files out of ./public as our main files
app.use(express.static(__dirname + '/public'))

app.set('trust proxy', 1) // trust first proxy
app.use(session({
  secret: 'keyboard cat',
  resave: false,
  saveUninitialized: true,
  // secure: true is required for production, but that requires an
  // HTTPS server, which is overkill for this demonstration
  cookie: { secure: false }
}))


app.get("/session", (req, res) => {
  res.send(req.sessionID)
})


app.get("/signature", (req, res) => {
  let error = "", realAddr = ""
  const expectedMsg = `My session ID: ${req.sessionID}`
  const hash = ethers.utils.id(`\x19Ethereum Signed Message:\n${expectedMsg.length}${expectedMsg}`)
  const claimedAddr = req.query.addr

  try {
    realAddr = ethers.utils.recoverAddress(hash, req.query.sig)
  } catch (err) {
    error = err.reason
  }

  if (error)  {
    res.send(`ERROR: ${error}`)
  } else {
    if (realAddr.toLowerCase() === claimedAddr.toLowerCase())
      res.send(`Legitimate, welcome ${realAddr}`)
    else
      res.send(`Fraud!!! You are not ${claimedAddr}, you are ${realAddr}!`)
  } // if (error) else

})     // app.get("signature")

app.get("*", (req,res) => {
  res.send(`
    <html>
      <body>
        <ul>
          <li><a href="/01_client_side.html">
                Client side user authentication</a>
          <li><a href="/02_server_side.html">
                Server side user authentication</a>
        </ul>
      </body>
    </html>
  `)
})

// start server on the specified port and binding host
app.listen(8000, '0.0.0.0', function() {
  console.log("server started");
})
