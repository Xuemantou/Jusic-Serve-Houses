const jsonFile = require('jsonfile');
const dataFile = require('./dataFile');

module.exports = () => {
  let allCookies = {};
  let userCookie = {};

  try {
    allCookies = jsonFile.readFileSync(dataFile('allCookies.json'))
  } catch (err) {
    // get allCookies failed
  }

  try {
    userCookie = jsonFile.readFileSync(dataFile('cookie.json'))
  } catch (err) {
    // get cookie failed
  }

  return {
    allCookies: () => allCookies,
    userCookie: () => userCookie,
    updateAllCookies: (v) => allCookies = v,
    updateUserCookie: (v) => userCookie = v,
  }
}
