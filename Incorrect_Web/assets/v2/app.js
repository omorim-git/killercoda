// v2: バージョンを更新（UIの表示とconsoleの両方）
const VERSION = "app.js v2";

(function () {
  const $ver = document.getElementById("version-info");
  const $time = document.getElementById("time-info");
  const $keyword = document.getElementById("keyword");

  const loadedAt = new Date();
  const timeStr = loadedAt.toLocaleString();

  if ($ver) $ver.textContent = `現在ロードされているJS: ${VERSION}`;
  if ($time) $time.textContent = `このJSを読み込んだ時刻: ${timeStr}`;
  if ($keyword) $keyword.textContent = `解答キーワード: 通信経路上の機器によるキャッシュに注意`;

  console.log(VERSION);
})();
