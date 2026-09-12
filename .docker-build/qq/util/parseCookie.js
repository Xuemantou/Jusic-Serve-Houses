/**
 * 解析浏览器「请求头 → Cookie」里复制出来的整串 cookie。
 *
 * 只按第一个 '=' 切分：cookie 值本身可能含 '='（base64 填充等），
 * 按 split('=') 取 [1] 会把这类值截断。
 *
 * @param {string} data 形如 "a=1; b=2; uin=123"
 * @returns {Object} cookie 键值对象，uin 已规整为纯数字
 */
module.exports = (data) => {
  const cookie = {};
  String(data || '').split(';').forEach((part) => {
    const item = part.trim();
    if (!item) {
      return;
    }
    const i = item.indexOf('=');
    if (i < 1) {
      return;
    }
    cookie[item.slice(0, i).trim()] = item.slice(i + 1);
  });

  // login_type 2 为微信登录，此时 uin 存在 wxuin 里
  if (Number(cookie.login_type) === 2) {
    cookie.uin = cookie.wxuin;
  }
  cookie.uin = String(cookie.uin || '').replace(/\D/g, '');
  return cookie;
};
