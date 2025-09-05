// v1: 画面とコンソールに現在のJSバージョンを明示
const VERSION = "app.js v1";

(function () {
  const $ver = document.getElementById("version-info");
  const $time = document.getElementById("time-info");

  // 読み込まれた瞬間の時刻（ブラウザ側）
  const loadedAt = new Date();
  const timeStr = loadedAt.toLocaleString();

  if ($ver) $ver.textContent = `現在ロードされているJS: ${VERSION}`;
  if ($time) $time.textContent = `このJSを読み込んだ時刻: ${timeStr}`;

  console.log(VERSION);
})();
