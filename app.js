var MB = window.LLK || {};

const CELL_SIZE = 56;
const PADDING = 12;
const TILE_TYPES = 16;
const ROWS = 8;
const COLS = 10;

const TILE_COLORS = [
  '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4',
  '#FFEAA7', '#DDA0DD', '#98D8C8', '#F7DC6F',
  '#BB8FCE', '#85C1E9', '#F8B500', '#00CED1',
  '#FF69B4', '#32CD32', '#FF7F50', '#9370DB',
];

const TILE_SYMBOLS = [
  '🍎', '🍊', '🍋', '🍇', '🍓', '🍒', '🥝', '🍑',
  '🌸', '🌺', '🌻', '🌹', '⭐', '💎', '🎯', '🎨',
];

let gameState = null;
let gameStarted = false;

const gameCanvas = document.getElementById('gameCanvas');
const overlayCanvas = document.getElementById('overlayCanvas');
const ctx = gameCanvas.getContext('2d');
const overlayCtx = overlayCanvas.getContext('2d');

const timerEl = document.getElementById('timer');
const progressEl = document.getElementById('progress');
const totalEl = document.getElementById('total');
const remainingEl = document.getElementById('remaining');
const statusMsg = document.getElementById('statusMsg');

let startTime = 0;
let timerInterval = null;
let elapsedSeconds = 0;
let animatingPath = null;
let animationStartTime = 0;

function boardWidth() { return COLS * CELL_SIZE + PADDING * 2; }
function boardHeight() { return ROWS * CELL_SIZE + PADDING * 2; }

function initCanvas() {
  gameCanvas.width = boardWidth();
  gameCanvas.height = boardHeight();
  overlayCanvas.width = boardWidth();
  overlayCanvas.height = boardHeight();
}

function cellCenter(r, c) {
  return {
    x: PADDING + c * CELL_SIZE + CELL_SIZE / 2,
    y: PADDING + r * CELL_SIZE + CELL_SIZE / 2,
  };
}

function getCellFromPos(x, y) {
  const c = Math.floor((x - PADDING) / CELL_SIZE);
  const r = Math.floor((y - PADDING) / CELL_SIZE);
  if (r >= 0 && r < ROWS && c >= 0 && c < COLS) {
    const relX = x - PADDING - c * CELL_SIZE;
    const relY = y - PADDING - r * CELL_SIZE;
    if (relX > 4 && relX < CELL_SIZE - 4 && relY > 4 && relY < CELL_SIZE - 4) {
      return { r, c };
    }
  }
  return null;
}

function drawRoundRect(x, y, w, h, r, fill, stroke) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
  if (fill) { ctx.fillStyle = fill; ctx.fill(); }
  if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 2; ctx.stroke(); }
}

function drawTile(r, c, value, isSelected) {
  const x = PADDING + c * CELL_SIZE;
  const y = PADDING + r * CELL_SIZE;
  const size = CELL_SIZE - 8;
  if (isSelected) {
    drawRoundRect(x - 2, y - 2, size + 4, size + 4, 10, null, '#FFD700');
    ctx.shadowColor = '#FFD700';
    ctx.shadowBlur = 12;
  }
  const colorIdx = (value - 1) % TILE_COLORS.length;
  drawRoundRect(x + 2, y + 2, size - 4, size - 4, 8, TILE_COLORS[colorIdx], null);
  ctx.shadowBlur = 0;
  const symbol = TILE_SYMBOLS[(value - 1) % TILE_SYMBOLS.length];
  ctx.font = '26px serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#fff';
  ctx.fillText(symbol, x + CELL_SIZE / 2, y + CELL_SIZE / 2);
}

function drawBoard() {
  ctx.clearRect(0, 0, gameCanvas.width, gameCanvas.height);
  if (!gameState) return;
  const rows = MB.get_rows(gameState);
  const cols = MB.get_cols(gameState);
  const selR = MB.get_selected_r(gameState);
  const selC = MB.get_selected_c(gameState);
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const value = MB.get_board_value(gameState, r, c);
      if (value !== 0) {
        drawTile(r, c, value, selR === r && selC === c);
      }
    }
  }
}

function drawPathAnimated() {
  if (!animatingPath) return;
  overlayCtx.clearRect(0, 0, overlayCanvas.width, overlayCanvas.height);
  const elapsed = (performance.now() - animationStartTime) / 400;
  const t = Math.min(elapsed, 1);
  const points = animatingPath;
  const totalSegments = points.length - 1;
  const progress = t * totalSegments;
  const fullSegments = Math.floor(progress);
  const partial = progress - fullSegments;
  overlayCtx.strokeStyle = '#FF4444';
  overlayCtx.lineWidth = 4;
  overlayCtx.lineCap = 'round';
  overlayCtx.lineJoin = 'round';
  overlayCtx.shadowColor = '#FF4444';
  overlayCtx.shadowBlur = 8;
  overlayCtx.beginPath();
  const p0 = cellCenter(points[0].y, points[0].x);
  overlayCtx.moveTo(p0.x, p0.y);
  for (let i = 0; i < fullSegments && i < totalSegments; i++) {
    const p = cellCenter(points[i + 1].y, points[i + 1].x);
    overlayCtx.lineTo(p.x, p.y);
  }
  if (fullSegments < totalSegments) {
    const start = cellCenter(points[fullSegments].y, points[fullSegments].x);
    const end = cellCenter(points[fullSegments + 1].y, points[fullSegments + 1].x);
    overlayCtx.lineTo(start.x + (end.x - start.x) * partial, start.y + (end.y - start.y) * partial);
  }
  overlayCtx.stroke();
  overlayCtx.shadowBlur = 0;
  if (t >= 1) {
    setTimeout(() => {
      animatingPath = null;
      overlayCtx.clearRect(0, 0, overlayCanvas.width, overlayCanvas.height);
      drawBoard();
      checkWin();
    }, 200);
  } else {
    requestAnimationFrame(drawPathAnimated);
  }
}

function updateUI() {
  if (!gameState) return;
  const matched = MB.get_matched_pairs(gameState);
  const total = MB.get_total_pairs(gameState);
  progressEl.textContent = matched;
  totalEl.textContent = total;
  remainingEl.textContent = total - matched;
}

function checkWin() {
  if (!gameState) return;
  if (MB.is_game_won(gameState)) {
    stopTimer();
    statusMsg.textContent = '🎉 恭喜通关！用时 ' + elapsedSeconds + ' 秒';
    statusMsg.className = 'status-msg win';
  }
}

function setStatus(msg, type) {
  statusMsg.textContent = msg;
  statusMsg.className = 'status-msg' + (type ? ' ' + type : '');
}

function startTimer() {
  if (timerInterval) return;
  startTime = Date.now();
  elapsedSeconds = 0;
  timerInterval = setInterval(() => {
    elapsedSeconds = Math.floor((Date.now() - startTime) / 1000);
    timerEl.textContent = elapsedSeconds;
  }, 250);
}

function stopTimer() {
  if (timerInterval) { clearInterval(timerInterval); timerInterval = null; }
}

function resetTimer() {
  stopTimer();
  elapsedSeconds = 0;
  timerEl.textContent = '0';
}

function newGame() {
  gameState = MB.init_game(ROWS, COLS, TILE_TYPES);
  gameStarted = false;
  resetTimer();
  animatingPath = null;
  overlayCtx.clearRect(0, 0, overlayCanvas.width, overlayCanvas.height);
  drawBoard();
  updateUI();
  setStatus('点击任意图案开始游戏，消除两个相同的图案（连线不超过两个拐点）');
}

function ensureTimerStarted() {
  if (!gameStarted) { gameStarted = true; startTimer(); }
}

function handleClick(e) {
  if (!gameState || animatingPath) return;
  const rect = gameCanvas.getBoundingClientRect();
  const cell = getCellFromPos(e.clientX - rect.left, e.clientY - rect.top);
  if (!cell) return;
  if (MB.is_game_won(gameState)) return;

  const clickResult = MB.handle_click(gameState, cell.r, cell.c);
  const newState = MB.click_get_state(clickResult);
  const pathResult = MB.click_get_path(clickResult);
  gameState = newState;
  const found = MB.path_found(pathResult);

  if (found) {
    ensureTimerStarted();
    const len = MB.path_len(pathResult);
    const pts = [];
    for (let i = 0; i < len; i++) {
      pts.push({ x: MB.path_point_x(pathResult, i), y: MB.path_point_y(pathResult, i) });
    }
    animatingPath = pts;
    animationStartTime = performance.now();
    requestAnimationFrame(drawPathAnimated);
    setStatus('匹配成功！');
  } else {
    if (MB.get_selected_r(gameState) !== -1) ensureTimerStarted();
    setStatus('请选择另一个相同的图案');
  }
  drawBoard();
  updateUI();
}

function handleShuffle() {
  if (!gameState || MB.is_game_won(gameState)) return;
  gameState = MB.shuffle_board(gameState);
  drawBoard();
  updateUI();
  setStatus('已重新洗牌');
}

function handleHint() {
  if (!gameState || MB.is_game_won(gameState)) return;
  const rows = MB.get_rows(gameState);
  const cols = MB.get_cols(gameState);
  const tiles = [];
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const v = MB.get_board_value(gameState, r, c);
      if (v !== 0) tiles.push({ r, c, v });
    }
  }
  const board = MB.get_board(gameState);
  for (let i = 0; i < tiles.length; i++) {
    for (let j = i + 1; j < tiles.length; j++) {
      if (tiles[i].v === tiles[j].v) {
        const pathResult = MB.find_path(board, rows, cols, tiles[i].r, tiles[i].c, tiles[j].r, tiles[j].c);
        if (MB.path_found(pathResult)) {
          const len = MB.path_len(pathResult);
          const pts = [];
          for (let k = 0; k < len; k++) {
            pts.push({ x: MB.path_point_x(pathResult, k), y: MB.path_point_y(pathResult, k) });
          }
          animatingPath = pts;
          animationStartTime = performance.now();
          requestAnimationFrame(drawPathAnimated);
          setStatus('提示: 位置 (' + (tiles[i].r+1) + ',' + (tiles[i].c+1) + ') 和 (' + (tiles[j].r+1) + ',' + (tiles[j].c+1) + ') 可消除');
          return;
        }
      }
    }
  }
  if (!MB.has_valid_moves(gameState)) {
    setStatus('没有可消除的配对了，请点击洗牌！', 'warn');
  } else {
    setStatus('正在寻找提示...');
  }
}

function initGame() {
  initCanvas();
  const loading = document.getElementById('loading');
  const game = document.getElementById('game');

  var missing = [];
  for (var k in MB) { if (!MB[k]) missing.push(k); }
  if (missing.length > 0 || !MB.init_game) {
    var errInfo = window.__llkError || '';
    var allKeys = Object.keys(window).filter(function(k) { return k.indexOf('_M0FP111lianliankan') === 0; });
    loading.innerHTML = '<h1>❌ 加载失败</h1>' +
      '<p style="margin-top:16px;color:#e53e3e;">MoonBit函数未加载 (' + missing.length + ' missing)</p>' +
      '<p style="margin-top:8px;color:#718096;">Bridge error: ' + errInfo + '</p>' +
      '<p style="margin-top:8px;color:#718096;">window上的MoonBit函数: ' + allKeys.length + ' 个</p>' +
      '<p style="margin-top:4px;color:#718096;font-size:12px;">' + allKeys.slice(0, 5).join(', ') + (allKeys.length > 5 ? '...' : '') + '</p>';
    return;
  }

  loading.classList.add('hidden');
  game.classList.remove('hidden');
  gameCanvas.addEventListener('click', handleClick);
  document.getElementById('btnNew').addEventListener('click', newGame);
  document.getElementById('btnShuffle').addEventListener('click', handleShuffle);
  document.getElementById('btnHint').addEventListener('click', handleHint);

  try {
    newGame();
  } catch (e) {
    loading.classList.remove('hidden');
    game.classList.add('hidden');
    loading.innerHTML = '<h1>❌ 初始化错误</h1><p style="margin-top:16px;color:#e53e3e;">' + e.message + '</p><pre style="margin-top:8px;font-size:12px;overflow:auto;max-height:200px;">' + e.stack + '</pre>';
  }
}

initGame();
