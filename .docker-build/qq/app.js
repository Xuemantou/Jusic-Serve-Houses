const createError = require('http-errors');
const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
const logger = require('morgan');
const fs = require('fs');
const DataStatistics = require('./util/dataStatistics');
const jsonFile = require('jsonfile');
const Feedback = require('./util/feedback');
const Cache = require('./util/cache');
const config = require('./bin/config');
const Request = require('./util/request');
const GlobalCookie = require('./util/globalCookie');
const parseCookie = require('./util/parseCookie');
const dataFile = require('./util/dataFile');

const app = express();
const dataHandle = new DataStatistics();
const feedback = new Feedback();
const cache = new Cache();
const globalCookie = GlobalCookie();

// 启动时若配置了 QqCookie，用它登记全局登录态。
// 这样 .env 就是唯一配置源：换 cookie 只需改 .env 再 up -d，容器重建也不会丢登录态。
// 注意 uin 必须等于本站的 QQ 号，否则 cookie 会被登记到别的账号名下。
if (process.env.QqCookie) {
  const cookie = parseCookie(process.env.QqCookie);
  const myQQ = String(process.env.QQ || config.qq || '');
  if (cookie.uin && cookie.uin === myQQ) {
    globalCookie.updateUserCookie(cookie);
    const allCookies = globalCookie.allCookies();
    allCookies[cookie.uin] = cookie;
    globalCookie.updateAllCookies(allCookies);
    try {
      jsonFile.writeFileSync(dataFile('cookie.json'), cookie);
      jsonFile.writeFileSync(dataFile('allCookies.json'), allCookies);
    } catch (err) {
      console.warn(`QQ 登录态落盘失败（内存已生效）：${err.message}`);
    }
    console.log(`已从 QqCookie 环境变量注入 QQ 登录态：uin=${cookie.uin}`);
  } else {
    console.warn(`QqCookie 已忽略：cookie 里 uin="${cookie.uin}" 与 QQ="${myQQ}" 不一致`);
  }
}

// 每10分钟存一下数据
config.useDataStatistics && setInterval(() => dataHandle.saveInfo(), 60000 * 10);

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'jade');

app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({extended: false}));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

config.useDataStatistics && app.use((req, res, next) => dataHandle.record(req, res, next));

const corsMap = {
  '/user/setCookie': true,
}
fs.readdirSync(path.join(__dirname, 'routes')).forEach(file => {
  const filename = file.replace(/\.js$/, '');
  const RouterMap = require(`./routes/${filename}`);
  Object.keys(RouterMap).forEach((path) => {
    app.use(`/${filename}${path}`, (req, res, next) => {
      const router = express.Router();
      const request = Request(req, res, {globalCookie})
      // 不注入 ownCookie：后端调用不带 cookie，必须回落到服务端登记的登录态
      req.query = {
        ...req.query,
        ...req.body,
      };
      // qq 登录
      let uin = (req.cookies.uin || '');
      // login_type 2 微信登录
      if (Number(req.cookies.login_type) === 2) {
        uin = req.cookies.wxuin;
      }
      req.cookies.uin = uin.replace(/\D/g, '');
      const func = RouterMap[path];

      const args = {request, dataStatistics: dataHandle, feedback, cache, globalCookie};
      router.post('/', (req, res) => func({req, res, ...args}));
      router.get('/', (req, res) => func({req, res, ...args}));
      if (corsMap[`/${filename}${path}`]) {
        router.options('/', (req, res) => {
          res.set('Access-Control-Allow-Origin', 'https://y.qq.com');
          res.set('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE');
          res.set('Access-Control-Allow-Headers', 'Content-Type');
          res.set('Access-Control-Allow-Credentials', 'true');
          res.sendStatus(200);
        })
      }
      router(req, res, next);
    })
  });
});

app.use('/', (req, res, next) => {
  const router = express.Router();
  router.get('/', (req, res) => require('./routes/index')['/'](req, res))
  router(req, res, next);
});

// catch 404 and forward to error handler
app.use(function (req, res, next) {
  next(createError(404));
});

// error handler
app.use(function (err, req, res, next) {
  // set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};

  // render the error page
  res.status(err.status || 500);
  res.render('error');
});

module.exports = app;
