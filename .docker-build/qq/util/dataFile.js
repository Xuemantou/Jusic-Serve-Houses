const path = require('path');

// 数据目录固定相对本文件定位，不依赖进程 cwd。
// 原先各处的 'data/xxx.json' 相对路径一旦 cwd 不为 /app/qq 就会静默读写失败。
module.exports = (name) => path.join(__dirname, '..', 'data', name);
